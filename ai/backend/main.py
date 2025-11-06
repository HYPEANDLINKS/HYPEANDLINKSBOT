from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import httpx
import os

app = FastAPI()

# CORS middleware to allow Flutter app to call this API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your Flutter app domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Ollama API URL - defaults to localhost, can be overridden with env var
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")
# Using tinyllama as default - smaller model that works on Railway free tier
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "tinyllama")


class ChatRequest(BaseModel):
    message: str


class ChatResponse(BaseModel):
    response: str


@app.get("/")
async def root():
    return {"status": "ok", "message": "AI Chat API is running"}


@app.post("/api/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """
    Send a message to Ollama and return the AI response
    """
    if not request.message or not request.message.strip():
        raise HTTPException(status_code=400, detail="Message cannot be empty")
    
    try:
        # Call Ollama API with optimized parameters for faster responses
        async with httpx.AsyncClient(timeout=25.0) as client:
            response = await client.post(
                f"{OLLAMA_URL}/api/generate",
                json={
                    "model": OLLAMA_MODEL,
                    "prompt": request.message,
                    "stream": False,
                    "options": {
                        "num_predict": 150,  # Limit response length for faster generation
                        "temperature": 0.7,   # Lower temperature for more focused responses
                    }
                }
            )
            
            # Check status and get error details if failed
            if response.status_code != 200:
                error_detail = "Unknown error"
                try:
                    error_data = response.json()
                    error_detail = error_data.get("error", str(response.text))
                except:
                    error_detail = response.text[:500]  # Limit error message length
                
                raise HTTPException(
                    status_code=503,
                    detail=f"Ollama error (status {response.status_code}): {error_detail}"
                )
            
            result = response.json()
            
            # Extract the response text
            ai_response = result.get("response", "No response generated")
            
            return ChatResponse(response=ai_response)
    
    except HTTPException:
        raise  # Re-raise HTTP exceptions
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Request timeout - AI model took too long to respond")
    except httpx.RequestError as e:
        raise HTTPException(
            status_code=503, 
            detail=f"Cannot connect to Ollama at {OLLAMA_URL}. Make sure Ollama is running. Error: {str(e)}"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)

