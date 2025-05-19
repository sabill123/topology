#!/usr/bin/env python3
"""Test password hashing"""

try:
    import bcrypt
    print(f"bcrypt version: {bcrypt.__version__ if hasattr(bcrypt, '__version__') else 'unknown'}")
    
    # Test bcrypt directly
    password = b"test123"
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password, salt)
    print(f"Direct bcrypt test: {bcrypt.checkpw(password, hashed)}")
    
except Exception as e:
    print(f"Bcrypt error: {e}")

try:
    from passlib.context import CryptContext
    
    # Test passlib with bcrypt
    pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
    plain_password = "test123"
    hashed_password = pwd_context.hash(plain_password)
    print(f"Passlib test: {pwd_context.verify(plain_password, hashed_password)}")
    
except Exception as e:
    print(f"Passlib error: {e}")

# Alternative approach
try:
    from passlib.hash import bcrypt as passlib_bcrypt
    
    # Test passlib bcrypt directly
    plain_password = "test123"
    hashed = passlib_bcrypt.hash(plain_password)
    print(f"Passlib bcrypt direct test: {passlib_bcrypt.verify(plain_password, hashed)}")
    
except Exception as e:
    print(f"Passlib bcrypt direct error: {e}")