package at.stderr.Inheritance;

import java.util.Arrays;
import java.util.List;

public class Burger extends Item {
    private List<String> toppings;
    public Burger(String name) {
        super(name, "burger");
    }

    public void addToppings(String[] toppings) {
        this.toppings.addAll(Arrays.asList(toppings));
    }

    public double getPrice() {
        // does not work
//        return super.price;
        return 0.0;
    }
}
