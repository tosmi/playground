package at.stderr.Inheritance;

public class OuterClass {
    private String outerClassDesc;
    private InnerBase innerBase;
    private InnerExtended innerExtended;

    public OuterClass() {
        outerClassDesc = "Hello from OuterClass";
        innerBase = new InnerBase("InnerBase description via OuterClass");
        innerExtended = new InnerExtended("InnerExtended description via OuterClass");
    }

    public void dumpOuterState () {
        System.out.println(this.getClass().getSimpleName() + " OuterClassDesc: " + outerClassDesc);
        System.out.println(this.getClass().getSimpleName() + " InnerBaseDesc: " + innerBase.innerBaseDesc);
        System.out.println(this.getClass().getSimpleName() + " InnerExtendedDesc: " + innerExtended.innerExtendeDesc);

        innerBase.dumpInnerState();
        innerExtended.dumpInnerExtendedState();
    }


    private class InnerBase {
        private String innerBaseDesc;

        public InnerBase(String description) {
            this.innerBaseDesc = description;
        }

        public void dumpInnerState() {
            System.out.println(this.getClass().getSimpleName() +  " OuterClassDesc: " + outerClassDesc);
            System.out.println(this.getClass().getSimpleName() +  " InnerBaseDesc: " + innerBaseDesc);

            // does not work of course
            System.out.println(this.getClass().getSimpleName() + " InnerExtendetDesc: " + innerExtended.innerExtendeDesc);
        }
    }
    private class InnerExtended extends InnerBase {
        private String innerExtendeDesc;

        public InnerExtended(String description) {
            super("via InnerExtended constructor");
            this.innerExtendeDesc = description;
        }

        public void dumpInnerExtendedState() {
            System.out.println(this.getClass().getSimpleName() + " OuterClassDesc: " + outerClassDesc);

            // XXX this works but dunno why...
            // this reference the superclass initialized via InnerExtended() constructor, prints "via InnerExtended constructor"
            System.out.println(this.getClass().getSimpleName() +  " InnerBaseDesc: " + super.innerBaseDesc);
            // this works which I understand
            // this references the private field of OuterClass, innerBase, initialized via the constructor OuterClass()
            System.out.println("%-15s%-20s: %s".formatted(this.getClass().getSimpleName(),"InnerBaseDesc", innerBase.innerBaseDesc));

            // complains about private field...
            // System.out.println(this.getClass().getSimpleName() +  " InnerBaseDesc: " + innerBaseDesc);

            System.out.println("%-15s%-20s: %s".formatted(this.getClass().getSimpleName(),"InnerExtendedDesc", innerExtendeDesc));
        }
    }
}
