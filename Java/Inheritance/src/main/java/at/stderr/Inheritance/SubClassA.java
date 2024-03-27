package at.stderr.Inheritance;

public class SubClassA extends BaseClass {
    private String subClassAPrivate;

    public SubClassA() {
        super();
        // does not work because private,
        // super.privateField = "bla";
    }
}
