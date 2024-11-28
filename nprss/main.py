import tkinter as tk

from database_handler import Database
from user_interfaces import UIHandler
from model.convolutional_nn import CNN

class Main():
    
    def __init__(self):
        self.database = Database()
        self.root = tk.Tk()
        self.model = CNN()
        self.model.load_model_parameters()
        self.uihandler = UIHandler(self.root, self.database, self.model)

    def run(self):
        self.root.mainloop()

if __name__ == "__main__":
    app = Main()
    app.run()
