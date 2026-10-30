import tflite

with open("assets/model/yolo_model.tflite", "rb") as f:
    data = f.read()

model = tflite.Model.GetRootAsModel(data, 0)

print("MODEL METADATA:")
for i in range(model.MetadataLength()):
    item = model.Metadata(i)
    print("Name:", item.Name().decode())
    print("Buffer index:", item.Buffer())

print("\nINPUT TENSOR:")
graph = model.Subgraphs(0)
for index in graph.InputsAsNumpy():
    tensor = graph.Tensors(int(index))
    print("Name:", tensor.Name().decode())
    print("Shape:", tensor.ShapeAsNumpy())
    print("Quantization:", tensor.Quantization())
