@echo off

pip install -r requirements.txt

pyinstaller -F --specpath spec --distpath . --clean cleanup.py

pause
