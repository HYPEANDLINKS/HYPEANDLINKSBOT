@echo off

REM Regenerate favicon from current logo SVG before build/deploy
echo Generating favicon from assets/HyperlinksSpace.svg...
py -3 scripts\svg_to_favicon.py
if errorlevel 1 (
    python scripts\svg_to_favicon.py
    if errorlevel 1 (
        echo Error: Python is required to generate favicon.
        echo Install Python dependency: pip install Pillow
        exit /b 1
    )
)

REM Build Flutter web app
echo Building Flutter web app...
flutter build web --release

REM Copy vercel.json and API functions to build directory
echo Copying Vercel configuration and API functions...
copy vercel.json build\web\vercel.json

REM Copy API serverless function
if exist api (
    if not exist build\web\api mkdir build\web\api
    xcopy /E /I /Y api build\web\api
    echo API functions copied
)

REM Deploy to Vercel
echo Deploying to Vercel...
cd build\web
vercel --prod


