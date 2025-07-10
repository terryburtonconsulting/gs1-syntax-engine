package org.gs1.gs1encoders;

import java.io.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.HashMap;
import java.util.Map;

/**
 * Native library loader for multi-architecture JAR support.
 * 
 * This class handles automatic detection of the runtime platform and loads
 * the appropriate native library from the JAR's resources.
 * 
 * @author Copyright (c) 2022-2025 GS1 AISBL.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 *
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
public class NativeLibraryLoader {
    
    private static final Map<String, String> PLATFORM_MAPPINGS = new HashMap<>();
    private static boolean loaded = false;
    
    static {
        // OS Name mappings
        PLATFORM_MAPPINGS.put("linux", "linux");
        PLATFORM_MAPPINGS.put("mac os x", "darwin");
        PLATFORM_MAPPINGS.put("windows", "windows");
        PLATFORM_MAPPINGS.put("freebsd", "freebsd");
        PLATFORM_MAPPINGS.put("openbsd", "openbsd");
        PLATFORM_MAPPINGS.put("netbsd", "netbsd");
        PLATFORM_MAPPINGS.put("sunos", "solaris");
    }
    
    /**
     * Load the native library with the specified name.
     * 
     * @param libraryName The name of the native library (without platform-specific prefix/suffix)
     * @throws UnsatisfiedLinkError if the library cannot be loaded
     */
    public static synchronized void load(String libraryName) throws UnsatisfiedLinkError {
        if (loaded) {
            return;
        }
        
        try {
            // Try system library first
            System.loadLibrary(libraryName);
            loaded = true;
            return;
        } catch (UnsatisfiedLinkError e) {
            // Fall back to bundled library
        }
        
        try {
            String platformPath = getPlatformPath();
            String libraryFileName = getLibraryFileName(libraryName);
            String resourcePath = "/META-INF/lib/" + platformPath + "/" + libraryFileName;
            
            // Check if running on Android
            if (isAndroid()) {
                loadFromAndroidAssets(resourcePath);
            } else {
                loadFromResources(resourcePath);
            }
            
            loaded = true;
        } catch (Exception e) {
            throw new UnsatisfiedLinkError("Failed to load native library: " + e.getMessage());
        }
    }
    
    /**
     * Get the platform-specific path component for the current system.
     */
    private static String getPlatformPath() {
        String osName = System.getProperty("os.name").toLowerCase();
        String osArch = System.getProperty("os.arch").toLowerCase();
        
        String platform = null;
        for (Map.Entry<String, String> entry : PLATFORM_MAPPINGS.entrySet()) {
            if (osName.contains(entry.getKey())) {
                platform = entry.getValue();
                break;
            }
        }
        
        if (platform == null) {
            throw new UnsatisfiedLinkError("Unsupported operating system: " + osName);
        }
        
        String arch = normalizeArch(osArch);
        return platform + "_" + arch;
    }
    
    /**
     * Normalize architecture names to standard values.
     */
    private static String normalizeArch(String arch) {
        if (arch.equals("x86_64") || arch.equals("amd64")) {
            return "x86_64";
        } else if (arch.equals("x86") || arch.equals("i386") || arch.equals("i686")) {
            return "x86";
        } else if (arch.equals("aarch64") || arch.equals("arm64")) {
            return "aarch64";
        } else if (arch.startsWith("arm")) {
            return "arm";
        } else {
            return arch;
        }
    }
    
    /**
     * Get the platform-specific library filename.
     */
    private static String getLibraryFileName(String libraryName) {
        String osName = System.getProperty("os.name").toLowerCase();
        
        if (osName.contains("windows")) {
            return libraryName + ".dll";
        } else if (osName.contains("mac")) {
            return "lib" + libraryName + ".dylib";
        } else {
            return "lib" + libraryName + ".so";
        }
    }
    
    /**
     * Check if running on Android.
     */
    private static boolean isAndroid() {
        try {
            Class.forName("android.app.Application");
            return true;
        } catch (ClassNotFoundException e) {
            return false;
        }
    }
    
    /**
     * Load library from JAR resources (standard Java).
     */
    private static void loadFromResources(String resourcePath) throws IOException {
        InputStream in = NativeLibraryLoader.class.getResourceAsStream(resourcePath);
        if (in == null) {
            throw new UnsatisfiedLinkError("Native library not found: " + resourcePath);
        }
        
        try {
            // Create temporary file
            String libraryFileName = resourcePath.substring(resourcePath.lastIndexOf('/') + 1);
            String prefix = libraryFileName.substring(0, libraryFileName.lastIndexOf('.'));
            String suffix = libraryFileName.substring(libraryFileName.lastIndexOf('.'));
            
            Path tempFile = Files.createTempFile(prefix, suffix);
            tempFile.toFile().deleteOnExit();
            
            // Copy library to temporary file
            Files.copy(in, tempFile, StandardCopyOption.REPLACE_EXISTING);
            
            // Load the library
            System.load(tempFile.toAbsolutePath().toString());
            
        } finally {
            in.close();
        }
    }
    
    /**
     * Load library from Android APK assets.
     */
    private static void loadFromAndroidAssets(String resourcePath) throws IOException {
        InputStream in = NativeLibraryLoader.class.getResourceAsStream(resourcePath);
        if (in == null) {
            throw new UnsatisfiedLinkError("Native library not found in APK: " + resourcePath);
        }
        
        try {
            // On Android, we need to extract to app's private directory
            // This requires Android context, which we'll get via reflection
            Object context = getAndroidContext();
            if (context == null) {
                throw new UnsatisfiedLinkError("Cannot get Android context for library extraction");
            }
            
            String libraryFileName = resourcePath.substring(resourcePath.lastIndexOf('/') + 1);
            
            // Use reflection to call context.getFilesDir()
            Object filesDir;
            try {
                filesDir = context.getClass().getMethod("getFilesDir").invoke(context);
            } catch (Exception e) {
                throw new IOException("Failed to get Android files directory: " + e.getMessage());
            }
            
            File libDir = new File((File) filesDir, "native-libs");
            if (!libDir.exists()) {
                libDir.mkdirs();
            }
            
            File libFile = new File(libDir, libraryFileName);
            
            // Extract library if not already present or if it's newer
            if (!libFile.exists() || shouldUpdateLibrary(libFile)) {
                FileOutputStream out = new FileOutputStream(libFile);
                try {
                    byte[] buffer = new byte[8192];
                    int read;
                    while ((read = in.read(buffer)) != -1) {
                        out.write(buffer, 0, read);
                    }
                } finally {
                    out.close();
                }
                
                // Set executable permissions
                libFile.setExecutable(true);
                libFile.setReadable(true);
            }
            
            // Load the library
            System.load(libFile.getAbsolutePath());
            
        } finally {
            in.close();
        }
    }
    
    /**
     * Get Android context using reflection to avoid compile-time Android dependency.
     */
    private static Object getAndroidContext() {
        try {
            // Try to get context from ActivityThread
            Class<?> activityThreadClass = Class.forName("android.app.ActivityThread");
            Object activityThread = activityThreadClass.getMethod("currentActivityThread").invoke(null);
            Object context = activityThreadClass
                .getMethod("getApplication").invoke(activityThread);
            return context;
        } catch (Exception e) {
            // Fall back to trying other methods
            try {
                Class<?> appGlobalsClass = Class.forName("android.app.AppGlobals");
                Object appGlobals = appGlobalsClass.getMethod("getInitialApplication").invoke(null);
                return appGlobals;
            } catch (Exception ex) {
                return null;
            }
        }
    }
    
    /**
     * Check if the library file should be updated.
     */
    private static boolean shouldUpdateLibrary(File libFile) {
        // For now, always update. In a production version, you might want to
        // check timestamps or version information.
        return true;
    }
}