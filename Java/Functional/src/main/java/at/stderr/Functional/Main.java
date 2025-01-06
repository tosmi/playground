package at.stderr.Functional;

import java.util.List;

/**
 * Hello world!
 *
 */
public class Main 
{
    public static void main( String[] args ) {

        List<String> myList = List.of("martha", "hanna", "emma", "toni");

        myList.forEach(System.out::println);

    }
}
