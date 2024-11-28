import os

import cv2
import numpy as np
import keras

character_map = {chr(i) : i - 55 for i in range(65, 91)}
character_map.update({str(i) : i for i in range(10)})

def segment_characters(path):
    image = cv2.imread(path)
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    _, threshold = cv2.threshold(gray, 150, 255, cv2.THRESH_BINARY_INV)
    countours, _ = cv2.findContours(threshold, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    characters = []
    for contour in countours:
        x_coord, y_coord, width, height = cv2.boundingRect(contour)

        if height > 15 and width > 5: # i need to do this otherwise noise is appended 
            character_image = threshold[y_coord : y_coord + height, x_coord : x_coord + width]
            character_image = cv2.resize(character_image, (32, 32))
            characters.append((x_coord, character_image))

    # we need to get the characters from left to right
    characters = sorted(characters, key=lambda x: x[0])
    return [character[1] for character in characters]

def create_character_dataset(plate_image_paths, plate_labels, save_dir):
    os.makedirs(save_dir, exist_ok=True)

    for index, (plate_image_path, plate_label) in enumerate(zip(plate_image_paths, plate_labels)):
        segmented_characters = segment_characters(plate_image_path)

        if len(segmented_characters) != len(plate_label): # something has gone wrong
            print(f"Character mismatch: {plate_image_path}")
            continue

        for character, character_label in zip(segmented_characters, plate_label):
            character_directory = os.path.join(save_dir, character_label)
            os.makedirs(character_directory, exist_ok=True)

            character_path = os.path.join(character_directory, f"{index}_{character_label}.png")
            cv2.imwrite(character_path, character)

def preprocess_character_dataset(dataset_directory, size=(32, 32), num_classes=36):
    X = []
    y = []

    for char_label in os.listdir(dataset_directory):
        char_dir = os.path.join(dataset_directory, char_label)
        for image_name in os.listdir(char_dir):
            image_path = os.path.join(char_dir, image_name)
            image = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
            resized = cv2.resize(image, size) / 255.0
            X.append(resized.reshape(size[0], size[1], 1))
            y.append(character_map[char_label])
    
    X = np.array(X, dtype=np.float32)
    y = keras.utils.to_categorical(y, num_classes=num_classes)
    return X, y

def preprocess_character(character_image):
    normalized = character_image / 255.0
    return normalized.reshape(32, 32, 1)
