import java.util.HashSet;

int sx = 600;
int sy = 550;
PFont f;

PImage barcode;
StringBuilder output;

HashMap<String, String> lcode = new HashMap<String, String>();
HashMap<String, String> gcode = new HashMap<String, String>();
HashMap<String, String> firstDigitMap = new HashMap<String, String>();

int[] widths = new int[59];
int samples = 10;
int[] detectedWidths = new int[4];
int[][] widthsMatrix = new int[samples][59];
int[] scanLines = new int[samples];
int threshold;

void setup() { 
  size(sx, sy);
  noLoop();

  barcode = loadImage("barcode3.jpg");
  barcode.filter(THRESHOLD);
    
  lcode.put("CBAA", "0");
  lcode.put("BBBA", "1");
  lcode.put("BABB", "2");
  lcode.put("ADAA", "3");
  lcode.put("AACB", "4");
  lcode.put("ABCA", "5");
  lcode.put("AAAD", "6");
  lcode.put("ACAB", "7");
  lcode.put("ABAC", "8");
  lcode.put("CAAB", "9");
  
  gcode.put("AABC", "0");
  gcode.put("ABBB", "1");
  gcode.put("BBAB", "2");
  gcode.put("AADA", "3");
  gcode.put("BCAA", "4");
  gcode.put("ACBA", "5");
  gcode.put("DAAA", "6");
  gcode.put("BACA", "7");
  gcode.put("CABA", "8");
  gcode.put("BAAC", "9");
  
  firstDigitMap.put("LLLLLL", "0");
  firstDigitMap.put("LLGLGG", "1");
  firstDigitMap.put("LLGGLG", "2");
  firstDigitMap.put("LLGGGL", "3");
  firstDigitMap.put("LGLLGG", "4");
  firstDigitMap.put("LGGLLG", "5");
  firstDigitMap.put("LGGGLL", "6");  
  firstDigitMap.put("LGLGLG", "7");
  firstDigitMap.put("LGLGGL", "8");
  firstDigitMap.put("LGGLGL", "9");
  
  output = new StringBuilder();
  
  f = createFont("Arial", 32, true); // Arial, 16 point, anti-aliasing on
  textFont(f);
  fill(0, 20, 10);
}

void displayResults() {  
  int heightd = barcode.height > sy ? barcode.height - sy : 0;
  int widthd = barcode.width > sx ? barcode.width - sx : 0;
  
  if (heightd > widthd) {
    barcode.resize(barcode.width * (sy/barcode.height), sy);
  } else if (heightd < widthd) {
    barcode.resize(sx, barcode.height * ((sx)/barcode.width));
  }
  
  image(barcode, 0, 0);
  
  StringBuilder sb = new StringBuilder();
  
  sb.append("Read number: " + output.charAt(0));
  
  for (int i = 1; i < output.length(); ++i) {
    if ((i-1) % 6 == 0) sb.append(" ");
    sb.append(output.charAt(i));
  }
  
  text(sb.toString(), sx/10, sy - 32);
  
  for (int i = 0; i < samples; ++i) {
    stroke(250, 10, 10);
    line(0, scanLines[i], barcode.width, scanLines[i]);
  }
}

void detectWidths() {
  for (int i = 0; i < 4; ++i) {
    detectedWidths[i] = -1;
  }
  
  detectedWidths[0] = widths[0];
  
  int c = 0;
  
  for (int i = 0; i < widths.length; ++i) {
    if (c == 4) break;
    boolean have = false;
    
    for (int j = 0; j < 4; ++j) {
      if(detectedWidths[j] == -1) continue;
      if (abs(widths[i] - detectedWidths[j]) < threshold) {
        have = true;
        break;
      }
    }
    
    if (!have) {
      detectedWidths[c++] = widths[i];
    }
  }
  
  for (int i = 0; i < 3; ++i) {
    for (int j = i; j < 4; ++j) {
      if (detectedWidths[i] > detectedWidths[j]) {
        detectedWidths[i] ^= detectedWidths[j];
        detectedWidths[j] ^= detectedWidths[i];
        detectedWidths[i] ^= detectedWidths[j];
      }
    }
  }
}

int pingBlack(int start, int end) {    
  boolean switched = false;
  if (start > end) {
    switched = true;
    start ^= end;
    end ^= start;
    start ^= end;
  }
  
  for (int i = start; i < end; ++i) {
    boolean found = false;
    
    for (int j = 0; j < barcode.width; ++j) {
      int pindex;
      
      if (!switched) {
        pindex = barcode.width * i + j;
      } else {
        pindex = barcode.width * (barcode.height - i - 1) + j;
      }
      
      float value = red(barcode.pixels[pindex]);

      if (value == 0) {
        if (!switched) {
          return i;
        } else {
          return barcode.height - i;
        }
      }
    }
  }
  
  return 0;
}

int getHalf() {
  return (pingBlack(0, barcode.height) + pingBlack(barcode.height, 0))/2;  
}

void flattenMatrix() {
  HashSet<Integer> discard = new HashSet<Integer>();

  for (int i = 0; i < samples; ++i) {
    for (int j = 0; j < widths.length; ++j) {
      if (widthsMatrix[i][j] == 0) {
        discard.add(i);
        break;
      }
    }
  }

  for (int i = 0; i < widths.length; ++i) {
    HashMap<Integer, Integer> agreeMap = new HashMap<Integer, Integer>();
    int maxAgreeCount = 0;
    int maxAgreeVal = 0;
  
    for (int j = 0; j < samples; ++j) {
      
      if (discard.contains(j)) {
        continue;
      }
      
      int agreeCount = 1;
      
      if (agreeMap.containsKey(widthsMatrix[j][i])) {
        agreeCount = agreeMap.get(widthsMatrix[j][i]) + 1;
      }
      
      agreeMap.put(new Integer(widthsMatrix[j][i]), new Integer(agreeCount));

      if (agreeCount > maxAgreeCount) {
        maxAgreeVal = widthsMatrix[j][i];
        maxAgreeCount = agreeCount;
      }
    }
    
    widths[i] = maxAgreeVal;
  }
}

void draw() {
  barcode.loadPixels();
  
  int start = pingBlack(0, barcode.height) + 10;
  int end = pingBlack(barcode.height, 0) - 10;
  int step = (end - start) / samples;
  
  for (int i = 0; i < samples; ++i) {
    scanLines[i] = start + i*step;
  }

  for (int s = 0; s < samples; ++s) {
    float lastValue = 255;
    int lastChangeX = 0;
    int windex = 0;
    boolean recording = false;
  
    //TODO testiraj  
    for (int i = 1; i < barcode.width - 1; i++) {
      int pindex = barcode.width * scanLines[s] + i;
      float value = red(barcode.pixels[pindex]);
      
      if (value != lastValue && recording) {
        widthsMatrix[s][windex++] = i - lastChangeX;
        lastChangeX = i;
      } else if (value != lastValue) {
        recording = true;
      } else if (!recording) {
        lastChangeX = i;
      }
      
      lastValue = value;
    }
  }
  
  flattenMatrix();

  threshold = widths[0]/2;
  
  char[] codes = new char[48];
  int c = 0;

  detectWidths();
  
  for (int i = 3; i < widths.length - 3; ++ i) {
    if (i >= 27 && i < 32) continue;
    
    int min = 10000;
    char code = 'C';
    char[] codeMap = {'A', 'B', 'C', 'D'}; 
    
    for(int k = 0; k < 4; ++k) {
      int correctWidth = detectedWidths[k];
      int diff = abs(widths[i] - correctWidth);
      
      if (diff < min) {
        min = diff;
        code = codeMap[k];
      }
    }
    
    codes[c++] = code;
  }
  
  StringBuilder buffer = new StringBuilder();
  StringBuilder firstDigitCode = new StringBuilder();
  
  for (int i = 0; i < 12; ++i) {
    for (int j = 0; j < 4; ++j) {
      buffer.append(codes[i*4 + j]);
    }
    
    String code = buffer.toString();
    String digit;
    
    if (i < 6) {
      if (lcode.containsKey(code)) {
        digit = lcode.get(code);
        firstDigitCode.append("L");
      } else {
        digit = gcode.get(code);
        firstDigitCode.append("G");
      }
    } else {
      digit = lcode.get(code);
    }
        
    output.append(digit);
    buffer = new StringBuilder();
  }
  
  String firstDigit = firstDigitMap.get(firstDigitCode.toString());
  output = new StringBuilder(firstDigit + output);
  
  displayResults();
}

