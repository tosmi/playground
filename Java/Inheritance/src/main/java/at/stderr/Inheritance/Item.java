package at.stderr.Inheritance;

public class Item {
    private String name;
    private String type;
    private double price;

    public Item(String name, String type) {
        this(name, type, 0);
    }
    public Item(String name, String type, double price) {
        this.name = name;
        this.type = type;
        this.price = price;
    }

    @Override
    public String toString() {
        return "%10s%15s $%.2f".formatted(type, name,
                // can call static method without class name in class
                getPrice(price, 0));

    }

    public static double getPrice(double price, double rate) {
        return price * rate;
    }
}
