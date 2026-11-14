public class Triangle {

    // Returns a^2 + b^2 - c^2, where c is the longest side.
    private static double test(double x, double y, double z) {
        double c = Math.max(x, Math.max(y, z));
        double a = Math.min(x, Math.min(y, z));
        double b = x + y + z - a - c;
        return a * a + b * b - c * c;
    }

    public static boolean areTriangular(double a, double b, double c) {
        return a > 0 && b > 0 && c > 0 && a < b + c && b < a + c && c < a + b;
    }

    public static boolean acuteTriangle(double a, double b, double c) {
        return areTriangular(a, b, c) && test(a, b, c) > 0.000001;
    }

    public static boolean rightTriangle(double a, double b, double c) {
        return areTriangular(a, b, c) && Math.abs(test(a, b, c)) <= 0.000001;
    }

    public static boolean obtuseTriangle(double a, double b, double c) {
        return areTriangular(a, b, c) && test(a, b, c) < -0.000001;
    }

    public static boolean scaleneTriangle(double a, double b, double c) {
        return areTriangular(a, b, c) && a != b && b != c && a != c;
    }

    public static boolean isoscelesTriangle(double a, double b, double c) {
        return areTriangular(a, b, c) && (a == b || b == c || a == c);
    }

    public static boolean equilateralTriangle(double a, double b, double c) {
        return areTriangular(a, b, c) && a == b && b == c;
    }
}
