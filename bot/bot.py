import os
import asyncio
import json
from dotenv import load_dotenv
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ApplicationBuilder, CommandHandler, MessageHandler, ContextTypes, filters
from telegram.error import Conflict, TelegramError
import asyncpg
import httpx
from datetime import datetime, timezone

load_dotenv()

# Database connection pool
_db_pool = None


async def get_db_pool():
    """Get or create database connection pool"""
    global _db_pool
    if _db_pool is None:
        database_url = os.getenv('DATABASE_URL')
        if not database_url:
            raise ValueError("DATABASE_URL environment variable is not set")
        
        # For local development on Windows, handle SSL certificate issues
        # In production (Railway), SSL will work fine
        import ssl
        
        try:
            # Try with SSL first (required for Neon)
            ssl_context = ssl.create_default_context()
            _db_pool = await asyncpg.create_pool(
                database_url,
                ssl=ssl_context
            )
        except Exception as e:
            # If SSL fails on Windows, try with relaxed SSL settings
            print(f"SSL connection failed with default context: {e}")
            print("Trying with relaxed SSL settings for local development...")
            ssl_context = ssl.create_default_context()
            ssl_context.check_hostname = False
            ssl_context.verify_mode = ssl.CERT_NONE
            try:
                _db_pool = await asyncpg.create_pool(
                    database_url,
                    ssl=ssl_context
                )
            except Exception as e2:
                print(f"SSL connection failed even with relaxed settings: {e2}")
                raise
    return _db_pool


async def init_db():
    """Initialize database - create users table if it doesn't exist"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                telegram_id BIGINT UNIQUE NOT NULL,
                username VARCHAR(255),
                first_name VARCHAR(255),
                last_name VARCHAR(255),
                language_code VARCHAR(10),
                created_at TIMESTAMP DEFAULT ((now() AT TIME ZONE 'UTC') + INTERVAL '3 hours'),
                updated_at TIMESTAMP DEFAULT ((now() AT TIME ZONE 'UTC') + INTERVAL '3 hours'),
                last_active_at TIMESTAMP DEFAULT ((now() AT TIME ZONE 'UTC') + INTERVAL '3 hours')
            )
        """)
        # Create index on telegram_id for faster lookups
        await conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_users_telegram_id ON users(telegram_id)
        """)
        print("Database initialized: users table created/verified")


async def save_user_async(update: Update):
    """Save or update user in database asynchronously (non-blocking)"""
    try:
        pool = await get_db_pool()
        user = update.effective_user
        
        async with pool.acquire() as conn:
            # Use PostgreSQL's INSERT ... ON CONFLICT for atomic upsert in ONE query
            # This is much faster than checking existence first
            # All timestamps use UTC+3 timezone (Moscow time)
            await conn.execute("""
                INSERT INTO users (telegram_id, username, first_name, last_name, language_code, last_active_at)
                VALUES ($1, $2, $3, $4, $5, (now() AT TIME ZONE 'UTC') + INTERVAL '3 hours')
                ON CONFLICT (telegram_id) 
                DO UPDATE SET 
                    username = EXCLUDED.username,
                    first_name = EXCLUDED.first_name,
                    last_name = EXCLUDED.last_name,
                    language_code = EXCLUDED.language_code,
                    last_active_at = (now() AT TIME ZONE 'UTC') + INTERVAL '3 hours',
                    updated_at = (now() AT TIME ZONE 'UTC') + INTERVAL '3 hours'
            """, 
                user.id,
                user.username,
                user.first_name,
                user.last_name,
                user.language_code
            )
    except Exception as e:
        print(f"Error saving user to database: {e}")


async def ensure_user_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handler that ensures user exists in database (runs on all messages, non-blocking)"""
    # Run database operation asynchronously without blocking the response
    asyncio.create_task(save_user_async(update))
    # Don't return anything - let other handlers process the update


async def hello(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    # Create inline keyboard with button
    app_url = os.getenv('APP_URL')
    keyboard = [
        [InlineKeyboardButton("Run app", url=f"{app_url}?mode=fullscreen")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        f"Hello, {update.effective_user.first_name}. That's Hype And Links, tap to enter",
        reply_markup=reply_markup
    )


async def stream_ai_response(message_text: str, bot, chat_id: int, message_id: int):
    """Stream AI response and edit message as chunks arrive"""
    ai_backend_url = os.getenv('AI_BACKEND_URL')
    api_key = os.getenv('API_KEY')
    if not api_key:
        raise ValueError("API_KEY environment variable must be set")
    
    accumulated_text = ""
    last_edit_time = asyncio.get_event_loop().time()
    edit_interval = 1.0  # Edit message every 1 second to avoid rate limits
    
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            async with client.stream(
                "POST",
                f"{ai_backend_url}/api/chat",
                json={"message": message_text},
                headers={
                    "Content-Type": "application/json",
                    "X-API-Key": api_key
                }
            ) as response:
                response.raise_for_status()
                
                async for line in response.aiter_lines():
                    if line:
                        try:
                            data = json.loads(line)
                            if "error" in data:
                                await bot.edit_message_text(
                                    chat_id=chat_id,
                                    message_id=message_id,
                                    text=f"Error: {data['error']}"
                                )
                                return
                            
                            if "token" in data:
                                accumulated_text += data["token"]
                            elif "response" in data:
                                accumulated_text = data["response"]
                            
                            # Edit message periodically to avoid rate limits
                            current_time = asyncio.get_event_loop().time()
                            if current_time - last_edit_time >= edit_interval:
                                # Telegram message limit is 4096 characters
                                display_text = accumulated_text[:4090] + "..." if len(accumulated_text) > 4090 else accumulated_text
                                if display_text:  # Only edit if we have text
                                    try:
                                        await bot.edit_message_text(
                                            chat_id=chat_id,
                                            message_id=message_id,
                                            text=display_text
                                        )
                                        last_edit_time = current_time
                                    except TelegramError as e:
                                        # If editing fails (e.g., message too long or same content), continue
                                        print(f"Warning: Could not edit message: {e}")
                            
                            if data.get("done", False):
                                break
                        except json.JSONDecodeError:
                            continue
                
                # Final edit with complete response
                final_text = accumulated_text[:4096] if len(accumulated_text) <= 4096 else accumulated_text[:4090] + "..."
                if final_text:
                    await bot.edit_message_text(
                        chat_id=chat_id,
                        message_id=message_id,
                        text=final_text
                    )
                else:
                    await bot.edit_message_text(
                        chat_id=chat_id,
                        message_id=message_id,
                        text="Sorry, I didn't receive a response."
                    )
    except httpx.TimeoutException:
        await bot.edit_message_text(
            chat_id=chat_id,
            message_id=message_id,
            text="Sorry, the AI took too long to respond. Please try again."
        )
    except httpx.RequestError as e:
        await bot.edit_message_text(
            chat_id=chat_id,
            message_id=message_id,
            text=f"Sorry, I couldn't connect to the AI service. Error: {str(e)}"
        )
    except Exception as e:
        await bot.edit_message_text(
            chat_id=chat_id,
            message_id=message_id,
            text=f"Sorry, an error occurred: {str(e)}"
        )


async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Handle arbitrary text messages with AI responses"""
    if not update.message or not update.message.text:
        return
    
    message_text = update.message.text.strip()
    
    # Skip if message is empty or is a command
    if not message_text or message_text.startswith('/'):
        return
    
    # Send initial "thinking" message
    sent_message = await update.message.reply_text("Thinking...")
    
    # Stream AI response and edit the message as chunks arrive
    await stream_ai_response(
        message_text,
        context.bot,
        sent_message.chat_id,
        sent_message.message_id
    )


async def post_init(app):
    """Delete webhook and initialize database on startup"""
    # Delete webhook before starting polling to avoid conflicts
    try:
        await app.bot.delete_webhook(drop_pending_updates=True)
        print("Webhook deleted (if it existed)")
        # Small delay to ensure webhook deletion is processed
        await asyncio.sleep(1)
    except Exception as e:
        print(f"Note: Could not delete webhook: {e}")
    
    # Initialize database
    try:
        await init_db()
        print("Database connection established")
    except Exception as e:
        print(f"Warning: Could not initialize database: {e}")
        print("Bot will continue but user data won't be saved")


async def shutdown(app):
    """Close database pool on shutdown"""
    global _db_pool
    if _db_pool:
        await _db_pool.close()
        print("Database connection closed")


def main():
    bot_token = os.getenv('BOT_TOKEN')
    if not bot_token:
        raise ValueError("Environment variable 'BOT_TOKEN' is not set")
    
    app = ApplicationBuilder().token(bot_token).post_init(post_init).post_shutdown(shutdown).build()
    
    # Add handler to ensure user exists in DB on every message (non-blocking)
    # This runs first, before command handlers
    app.add_handler(MessageHandler(filters.ALL, ensure_user_handler), group=-1)
    
    # Add command handlers
    app.add_handler(CommandHandler("start", hello))
    
    # Add handler for arbitrary text messages (AI responses)
    # This should run after command handlers, so commands are processed first
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    
    print("Bot starting...")
    try:
        app.run_polling(drop_pending_updates=True, allowed_updates=Update.ALL_TYPES)
    except Conflict as e:
        print("Error: Another bot instance is already running or webhook conflict exists.")
        print("This usually resolves automatically. If it persists, check for other running instances.")
        print(f"Details: {e}")
        # Don't re-raise, just exit gracefully
        return
    except KeyboardInterrupt:
        print("\nBot stopped by user")
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()


if __name__ == '__main__':
    main()
