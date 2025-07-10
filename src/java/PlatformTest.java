import org.gs1.gs1encoders.*;

public class PlatformTest {
    public static void main(String[] args) {
        System.out.println("=== Multi-Architecture JAR Platform Detection Test ===");
        
        // Display current platform info
        String osName = System.getProperty("os.name");
        String osArch = System.getProperty("os.arch");
        String javaVersion = System.getProperty("java.version");
        
        System.out.println("Operating System: " + osName);
        System.out.println("Architecture: " + osArch);
        System.out.println("Java Version: " + javaVersion);
        
        try {
            // This will trigger the NativeLibraryLoader
            GS1Encoder encoder = new GS1Encoder();
            System.out.println("✅ Successfully loaded GS1 Encoder");
            System.out.println("Library Version: " + encoder.getVersion());
            
            // Test basic functionality
            encoder.setAIdataStr("(01)12345678901231");
            System.out.println("GTIN Barcode Data: " + encoder.getDataStr());
            System.out.println("Digital Link URI: " + encoder.getDLuri(null));
            
            encoder.free();
            System.out.println("✅ Multi-architecture JAR test completed successfully!");
            
        } catch (Exception e) {
            System.err.println("❌ Error loading native library: " + e.getMessage());
            e.printStackTrace();
        }
    }
}