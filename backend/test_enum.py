import enum
class OrderStatus(str, enum.Enum):
    DISPATCHED = "Dispatched"

print("Enum == str:", OrderStatus.DISPATCHED == "Dispatched")
print("Enum != str:", OrderStatus.DISPATCHED != "Dispatched")
