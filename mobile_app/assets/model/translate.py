import tensorflow as tf

# 1. Save කරපු model එක load කරගන්න
model = tf.keras.models.load_model('mobilenet_paper_model.keras')

# 2. TFLite Converter එක මඟින් convert කරන්න
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

# 3. .tflite ෆයිල් එකක් ලෙස save කරගන්න
with open('mobilenet_paper_model.tflite', 'wb') as f:
    f.write(tflite_model)

print("✅ Successfully converted to mobilenet_paper_model.tflite")