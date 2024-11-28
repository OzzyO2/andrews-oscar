import numpy as np

from convolutional_nn import CNN
from stochastic_optimiser import SGD
from preprocessing import preprocess_character_dataset

# training data here
training_directory = r".\model\training_characters"
testing_directory = r".\model\testing_characters"
X_train, y_train = preprocess_character_dataset(training_directory)
X_test, y_test = preprocess_character_dataset(testing_directory)

# using default arguments for both
cnn = CNN()
sgd = SGD()

epochs = 100
batch_size = 32 # this number just works better for some reason, wonder why
for epoch in range(epochs):
    indices = np.arange(X_train.shape[0]) # we shuffle the data to help with the batch training
    np.random.shuffle(indices)
    X_train = X_train[indices]
    y_train = y_train[indices]

    for i in range(0, X_train.shape[0], batch_size): # faster than doing all the data every single time
        X_batch = X_train[i:i + batch_size]
        y_batch = y_train[i:i + batch_size]

        predictions = cnn.forwardprop(X_batch)
        loss = cnn.loss(predictions, y_batch)
        gradients = cnn.gradients(predictions, y_batch)
        sgd.update(
            [cnn.fully_connected_weights, cnn.fully_connected_bias],
            [np.dot(cnn.flattened.T, gradients), np.sum(gradients, axis=0)]
        )

    if epoch % 5 == 0:
        print(f"Epoch: {epoch}, Loss: {loss}")

accuracy = cnn.evaluate(X_test, y_test)
print(f"Accuracy: {accuracy * 100}%")
cnn.save_model_parameters()
