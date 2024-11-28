class SGD:

    def __init__(self, learning_rate=0.01):
        self.learning_rate = learning_rate

    def update(self, parameters, gradients):
        for i in range(len(parameters)):
            parameters[i] -= self.learning_rate * gradients[i]
