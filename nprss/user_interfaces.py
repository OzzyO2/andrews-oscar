import ttkbootstrap as ttk
from ttkbootstrap.dialogs import Messagebox
from tkinter import filedialog
from PIL import Image, ImageTk

from model import preprocessing

class UIHandler:

    def __init__(self, root, database, model):
        self.root = root
        self.database = database
        self.model = model
        self.login_page = LoginUI(self, root, database)
        self.dashboard_page = None
    
    def display_login(self):
        if self.dashboard_page:
            for w in self.root.winfo_children():
                w.destroy()
        self.login_page.create_widgets()

    def display_dashboard(self):
        for w in self.root.winfo_children():
            w.destroy()
        self.dashboard_page = DashboardUI(self.root, self.database, self.model)

class LoginUI:
    def __init__(self, uihandler, root, database):
        self.root = root
        self.uihandler = uihandler
        self.database = database
        self.style = ttk.Style("darkly")
        self.root.title("NPRSS - Login")
        self.root.geometry("400x300")
        self.create_widgets()

    def create_widgets(self):
        label_title = ttk.Label(self.root, text="Number Plate Recognition System", font=("Helvetica", 18))
        label_title.pack(pady=10)

        label_username = ttk.Label(self.root, text="Username:")
        label_username.pack(pady=5)
        self.entry_username = ttk.Entry(self.root, width=30)
        self.entry_username.pack(pady=5)

        label_password = ttk.Label(self.root, text="Password:")
        label_password.pack(pady=5)
        self.entry_password = ttk.Entry(self.root, width=30, show="*")
        self.entry_password.pack(pady=5)

        button_login = ttk.Button(self.root, text="Login", command=self.login, width=20)
        button_login.pack(pady=20)

    def login(self):
        username = self.entry_username.get()
        password = self.entry_password.get()

        if not username or not password:
            Messagebox.show_error("Enter a username and a password please", "Error!")
            return

        user = self.database.validate_user(username, password)
        print(user)
        if user == "admin":
            print("Displaying the dashboard now...")
            self.uihandler.display_dashboard()
        else:
            Messagebox.show_error("Invalid username or password. (user: admin, pass: admin) :)", "Login Failed!")

class DashboardUI:
    
    def __init__(self, root, database, model):
        self.root = root
        self.database = database
        self.model = model
        self.style = ttk.Style("darkly")
        self.root.title("NPRSS - User Dashboard")
        self.root.geometry("600x400")
        self.create_widgets()

    def create_widgets(self):
        label_title = ttk.Label(self.root, text="NPRSS Dashboard :)", font=("Arial", 16))
        label_title.pack(pady=10)

        label_upload = ttk.Label(self.root, text="Upload Number Plate Image:")
        label_upload.pack(pady=10)
        button_upload = ttk.Button(self.root, text="Upload Image", command=self.upload_image)
        button_upload.pack(pady=5)

        self.output_frame = ttk.Frame(self.root)
        self.output_frame.pack(pady=10)
        self.output_label = ttk.Label(self.output_frame, text="", wraplength=500)
        self.output_label.pack()

        self.image_label = ttk.Label(self.root)
        self.image_label.pack(pady=20)

    def upload_image(self):
        file_path = filedialog.askopenfilename(
        title="Select a License Plate Image",
        filetypes=(("Image Files", "*.png;*.jpg;*.jpeg"), ("All Files", "*.*"))
        )
        if not file_path:
            self.output_label.config(text="No file selected.")
            return
        segmented_characters = preprocessing.segment_characters(file_path)
        if not segmented_characters:
            self.output_label.config(text="No characters detected in the image.")
            return
        
        image = Image.open(file_path)
        image = image.resize((300, 100))
        photo = ImageTk.PhotoImage(image)
        self.image_label.config(image=photo)
        self.image_label.image = photo
        self.output_label.config(text=f"Image uploaded: {file_path}")

        license_plate = self.model.predict_characters(segmented_characters) # needs fixing
        self.output_label.config(text=f"Recognized License Plate: {license_plate}")
