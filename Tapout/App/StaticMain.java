import java.util.Scanner;

public class StaticMain {

    public static void main(String[] args) {

        Scanner in = new Scanner(System.in);
        System.out.print("Enter the first side length: ");
        double a = in.nextDouble();
        System.out.print("Enter the second side length: ");
        double b = in.nextDouble();
        System.out.print("Enter the third side length: ");
        double c = in.nextDouble();

        String text = "A triangle with side lengths of " + a + ", " + b + " and " + c;

        if (!Triangle.areTriangular(a, b, c)) {
            System.out.println(text + " cannot exist.");
        } else {
            String angle = "";
            if (Triangle.acuteTriangle(a, b, c)) {
                angle = "Acute";
            } else if (Triangle.rightTriangle(a, b, c)) {
                angle = "Right";
            } else if (Triangle.obtuseTriangle(a, b, c)) {
                angle = "Obtuse";
            }

            String sides = "";
            if (Triangle.equilateralTriangle(a, b, c)) {
                sides = "Equilateral";
            } else if (Triangle.isoscelesTriangle(a, b, c)) {
                sides = "Isosceles";
            } else if (Triangle.scaleneTriangle(a, b, c)) {
                sides = "Scalene";
            }

            System.out.println(text + " is " + angle + " " + sides + " triangle");
        }
    }
}
