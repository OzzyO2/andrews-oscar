# run this to get all the synth LP's needed and their segmented characters for training

import random
import string
import os

from PIL import Image, ImageDraw, ImageFont

from preprocessing import create_character_dataset

def generate_license_plate(text, output_path, plate_size=(300, 100), font_path=r"model\lp_font\UKNumberPlate.ttf"):
    plate = Image.new("RGB", plate_size, color=(255, 255, 0)) # yellow bg

    draw = ImageDraw.Draw(plate)
    font = ImageFont.truetype(font_path, size=65)

    text_bbox = font.getbbox(text)
    text_width = text_bbox[2] - text_bbox[0]
    text_height = text_bbox[3] - text_bbox[1]
    text_x = (plate_size[0] - text_width) // 2
    text_y = (plate_size[1] - text_height) // 2

    draw.text((text_x, text_y), text, fill="black", font=font)

    plate.save(output_path)
    print(f"License plate saved to {output_path}")

def random_plate():
    format_choice = random.choice(["ABC 123", "AB12 XYZ"])
    if format_choice == "ABC 123":
        return "".join(random.choices(string.ascii_uppercase, k=3)) + " " + "".join(random.choices(string.digits, k=3))
    elif format_choice == "AB12 XYZ":
        return "".join(random.choices(string.ascii_uppercase, k=2)) + "".join(random.choices(string.digits, k=2)) + " " + "".join(random.choices(string.ascii_uppercase, k=3))

def generate_batch_plates(output_dir, num_plates=50, font_path=r"model\lp_font\UKNumberPlate.ttf"):
    os.makedirs(output_dir, exist_ok=True)

    num_plates_generated = 0
    generated_plates = set()
    while num_plates_generated < num_plates:
        plate_text = random_plate()
        if plate_text in generated_plates: # don't want duplicate plates
            continue
        generated_plates.add(plate_text)
        num_plates_generated += 1
        output_path = os.path.join(output_dir, f"{plate_text.replace(' ', '')}.jpg")
        generate_license_plate(plate_text, output_path, font_path=font_path)

generate_batch_plates(r".\model\training_synthetic_plates", 1000)
generate_batch_plates(r".\model\testing_synthetic_plates", 50)
training_labels = [label.rstrip(".jpg") for label in os.listdir(r".\model\training_synthetic_plates")]
testing_labels = [label.rstrip(".jpg") for label in os.listdir(r".\model\testing_synthetic_plates")]

training_plate_directories = [
    os.path.join(root, file)
    for root, _, files in os.walk(r".\model\training_synthetic_plates")
    for file in files
    if file.lower().endswith((".jpg"))
]
testing_plate_directories = [
    os.path.join(root, file)
    for root, _, files in os.walk(r".\model\testing_synthetic_plates")
    for file in files
    if file.lower().endswith((".jpg"))
]

create_character_dataset(training_plate_directories, training_labels, r".\model\training_characters") # wants list of all plate image paths
create_character_dataset(testing_plate_directories, testing_labels, r".\model\testing_characters")
