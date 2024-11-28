import sqlite3
import bcrypt

class Database:
    def __init__(self, db_name="nprss.db"):
        self.db_name = db_name
        self.connection = None
        self.setup_database()

    def connect(self):
        self.connection = sqlite3.connect(self.db_name)

    def disconnect(self):
        if self.connection:
            self.connection.close()

    def setup_database(self):
        """Make all tables needed"""
        self.connect()
        cursor = self.connection.cursor()

        cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            role TEXT CHECK(role IN ('admin', 'user')) DEFAULT 'user'
        );
        """)

        self.add_user("admin", "admin", "admin", False)

        self.connection.commit()
        self.disconnect()

    def add_user(self, username, password, role="user", close_database=True):
        try:
            self.connect()
            cursor = self.connection.cursor()

            pass_hashed = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt())
            cursor.execute("""
            INSERT INTO users (username, password, role)
            VALUES (?, ?, ?);""", (username, pass_hashed, role))

            print(f"'{username}' added successfully")
            
            if close_database:
                self.connection.commit()
                self.disconnect()
        except sqlite3.IntegrityError as e:
            print(f"Error: {e}")
        
    def validate_user(self, username, password):
        try:
            self.connect()
            cursor = self.connection.cursor()
        
            cursor.execute("""
            SELECT password, role FROM users WHERE username = ?;
            """, (username,))
            result = cursor.fetchone()

            if result:
                stored_password, role = result
                if bcrypt.checkpw(password.encode('utf-8'), stored_password):
                    return role
            self.disconnect()
        except sqlite3.IntegrityError as e:
            print(f"Error: {e}")
