#!/bin/bash

# DerivedData 정리
rm -rf ~/Library/Developer/Xcode/DerivedData/topology-*

# 중복 파일 제거
find . -name "*.pyc" -delete
find . -name "__pycache__" -type d -exec rm -rf {} +
find . -name "*.py" -not -path "./venv/*" -delete

echo "빌드 준비 완료"