import os
import cv2 # type: ignore
import yaml # type: ignore
import numpy as np
import tensorflow as tf # type: ignore
import matplotlib.pyplot as plt # type: ignore

# 1. dataset folder path define
dataset_path = 'dataset/paper_craft_BALANCED'
train_img_dir = os.path.join(dataset_path, 'train/images')
train_lbl_dir = os.path.join(dataset_path, 'train/labels')
yaml_path = os.path.join(dataset_path, 'data.yaml')

# 2. data.yamal file class read
if os.path.exists(yaml_path):
    with open(yaml_path, 'r') as f:
        data = yaml.safe_load(f)
    classes = data['names']
    num_classes = len(classes)
    print(f" final Classes: {classes} (Total: {num_classes})")
else:
    print(f" Error: {yaml_path} file is not found. Using default class count of 3.")
    num_classes = 3

# 3. Load Dataset (Images & Labels)
IMG_SIZE = 224 

def load_dataset(image_dir, label_dir, img_size):
    images = []
    labels = []
    
    if not os.path.exists(image_dir):
        print(f" Error: {image_dir} folder is not found.")
        return np.array([]), np.array([])

    image_files = sorted(os.listdir(image_dir))
    
    for img_file in image_files:
        if not img_file.endswith(('.jpg', '.png', '.jpeg')):
            continue
            
        img_path = os.path.join(image_dir, img_file)
        img = cv2.imread(img_path)
        if img is None:
            continue
            
        img_resized = cv2.resize(img, (img_size, img_size))
        img_resized = img_resized / 255.0 # Normalization 

        # Corresponding Label File is expected to have the same name but with .txt extension
        txt_file = img_file.rsplit('.', 1)[0] + '.txt'
        txt_path = os.path.join(label_dir, txt_file)
        
        if os.path.exists(txt_path):
            with open(txt_path, 'r') as tf_file:
                line = tf_file.readline()
                if line:
                    parts = list(map(float, line.strip().split()))
                    if len(parts) >= 5:
                        cls_id = int(parts[0])
                        images.append(img_resized)
                        labels.append(cls_id)
                        
    return np.array(images, dtype=np.float32), np.array(labels, dtype=np.int32)

print("Dataset loading starting...")
X_train, y_train = load_dataset(train_img_dir, train_lbl_dir, IMG_SIZE)
print(f"Loaded {len(X_train)} training images.")

if len(X_train) > 0:
    print("dataset loaded successfully. Proceeding to model training...")
    
    # pre-trained MobileNetV2 model is loaded without the top classification layer, and weights are initialized from ImageNet.
    base_model = tf.keras.applications.MobileNetV2(
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
        include_top=False,
        weights='imagenet'
    )
    base_model.trainable = False

    #custom classification layers are added on top of the base model to adapt it for the specific task of classifying paper craft images.
    model = tf.keras.Sequential([
        base_model,
        tf.keras.layers.GlobalAveragePooling2D(),
        tf.keras.layers.Dense(128, activation='relu'),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(num_classes, activation='softmax')
    ])

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-4),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )

    print("Model architecture created and compiled successfully.")

    #3. Model Training
    EPOCHS = 10
    history = model.fit(
        X_train, y_train,
        epochs=EPOCHS,
        batch_size=4
    )

    # 4. Learning Curves (Accuracy & Loss Graphs) Save
    print("training completed. Saving training metrics graphs...")
    plt.figure(figsize=(12, 4))
    
    # Loss Plot
    plt.subplot(1, 2, 1)
    plt.plot(history.history['loss'], label='Training Loss', color='blue', marker='o')
    plt.title('Training Loss Curve')
    plt.xlabel('Epochs')
    plt.ylabel('Loss')
    plt.legend()
    plt.grid(True)

    # Accuracy Plot
    plt.subplot(1, 2, 2)
    plt.plot(history.history['accuracy'], label='Training Accuracy', color='green', marker='o')
    plt.title('Training Accuracy Curve')
    plt.xlabel('Epochs')
    plt.ylabel('Accuracy')
    plt.legend()
    plt.grid(True)

    # Save the combined graph as a PNG file in the dataset folder
    graph_save_path = os.path.join(dataset_path, 'training_metrics.png')
    plt.savefig(graph_save_path)
    plt.close()
    print(f"Saved training metrics graph: {graph_save_path}")

    # 5. Model එක Save කරගැනීම
    model_save_path = os.path.join(dataset_path, 'mobilenet_paper_model.keras')
    model.save(model_save_path)
    print(f"Saved model: {model_save_path}")

else:
    print(" No training data found. Please check the dataset folder and ensure that images and labels are present.")