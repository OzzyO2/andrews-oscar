import numpy as np
import pickle

from model.preprocessing import preprocess_character

class CNN:

    def __init__(self, input_shape=(32, 32, 1), num_classes=36):
        self.input_shape = input_shape
        self.num_classes = num_classes
        self.convolution_filters = np.random.randn(3, 3, input_shape[-1], 8) * 0.01
        self.fully_connected_weights = np.random.randn(8 * (30 ** 2), num_classes) * 0.01
        self.fully_connected_bias = np.zeros(num_classes)

    def relu(self, x):
        return np.maximum(0, x)
    
    def relu_derivative(self, x):
        if x < 0:
            return 0
        return 1
    
    def softmax(self, x): # we need this for the final connected layer as the activation function
        self.x = x
        expo = np.exp(self.x - np.max(self.x, axis=1, keepdims=True))
        return expo / np.sum(expo, axis=1, keepdims=True)
    
    def forwardprop(self, x):
        self.x = x
        self.convolution_output = self.convolve(self.x, self.convolution_filters)
        self.convolution_activated = self.relu(self.convolution_output)

        # we need the output of the convolution to be flattened otherwise this spits out a value error
        batch_size, height, width, channels = self.convolution_activated.shape
        flattened_size = height * width * channels
        self.flattened = self.convolution_activated.reshape(batch_size, flattened_size)

        if self.fully_connected_weights is None:
            self.fully_connected_weights = np.random.randn(flattened_size, self.num_classes) * 0.01
            self.fully_connected_bias = np.zeros(self.num_classes)

        self.fully_connected_output = np.dot(self.flattened, self.fully_connected_weights) + self.fully_connected_bias
        return self.softmax(self.fully_connected_output)
    
    def convolve(self, x, filters):
        batch_size, height, width, channels = x.shape
        filter_height, filter_width, _, num_filters = filters.shape
        output_height = height - filter_height + 1
        output_width = width - filter_width + 1
        output = np.zeros((batch_size, output_height, output_width, num_filters))

        for i in range(output_height):
            for j in range(output_width):
                region = x[:, i:i + filter_height, j:j + filter_width, :]
                # this is just black magic at this point
                output[:, i, j, :] = np.tensordot(region, filters, axes=((1, 2, 3), (0, 1, 2)))
        return output
    
    def backwardprop(self, gradients, learning_rate=0.01): # for fully connected layer
        fully_connected_gradients = gradients
        flattened_gradients = np.dot(fully_connected_gradients, self.fully_connected_weights.T).reshape(self.convolution_activated.shape)
        self.fully_connected_weights -= learning_rate * np.dot(self.flattened.T, fully_connected_gradients)
        self.fully_connected_bias -= learning_rate * np.sum(fully_connected_gradients, axis=0)
        convolutional_gradient = flattened_gradients * self.relu_derivative(self.convolution_output)
        return convolutional_gradient
    
    def loss(self, predictions, labels):
        return -1 * (np.mean(np.sum(labels * np.log(predictions), axis=1)))

    def gradients(self, predictions, labels):
        return predictions - labels
    
    def predict_characters(self, characters_segmented):
        class_map = {i: str(i) for i in range(10)}
        class_map.update({i + 10: chr(65 + i) for i in range(26)})

        predictions = []
        for character_image in characters_segmented:
            preprocessed = preprocess_character(character_image)
            preprocessed = np.expand_dims(preprocessed, axis=0)
            prediction = self.forwardprop(preprocessed)
            predicted_character = np.argmax(prediction)
            predictions.append(class_map[int(predicted_character)])
        return "".join(predictions)
    
    def evaluate(self, X_test, y_test):
        predictions = self.forwardprop(X_test)
        classes_predicted = np.argmax(predictions, axis=1)
        actual_classes = np.argmax(y_test, axis=1)
        accuracy = np.mean(classes_predicted == actual_classes)
        return accuracy
    
    def load_model_parameters(self, load_from=r".\model\saved_model_parameters.pkl"):
        with open(load_from, "rb") as file:
            parameters = pickle.load(file)
            self.convolution_filters = parameters["convolution_filters"]
            self.fully_connected_weights = parameters["fully_connected_weights"]
            self.fully_connected_bias = parameters["fully_connected_bias"]
    
    def save_model_parameters(self, save_to=r".\model\saved_model_parameters.pkl"):
        with open(save_to, "wb") as file:
            pickle.dump({
                "convolution_filters": self.convolution_filters,
                "fully_connected_weights": self.fully_connected_weights,
                "fully_connected_bias": self.fully_connected_bias,
            }, file)
