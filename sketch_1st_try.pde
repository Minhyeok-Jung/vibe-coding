// 점(다각형의 중심)의 개수
int NUM_POINTS = 300;
Point[] points = new Point[NUM_POINTS];

void setup() {
  size(800, 800);
  noLoop(); // 정적 맵이므로 한 번만 렌더링합니다.
  
  println("맵 생성 중...");
  
  // 1. 포인트 무작위 생성
  for (int i = 0; i < NUM_POINTS; i++) {
    points[i] = new Point(random(width), random(height));
  }
  
  // 2. 로이드 이완(Lloyd Relaxation) 적용
  // 점들을 고르게 펴서 예쁜 다각형 모양을 만듭니다. (반복할수록 정교해짐)
  for (int i = 0; i < 3; i++) {
    relaxPoints();
    println("로이드 이완 " + (i+1) + "/3 완료");
  }
  
  // 3. 중심점들에 고도(Elevation) 및 수분(Moisture) 할당
  assignAttributes();
  
  println("렌더링 완료!");
}

void draw() {
  background(0);
  loadPixels();
  
  // 4. 픽셀 단위 렌더링 (보로노이 다이어그램 그리기)
  for (int x = 0; x < width; x++) {
    for (int y = 0; y < height; y++) {
      int closestIndex = 0;
      float minDist = width * height;
      
      // 각 픽셀에서 가장 가까운 중심점(Cell) 찾기
      for (int i = 0; i < NUM_POINTS; i++) {
        float d = dist(x, y, points[i].x, points[i].y);
        if (d < minDist) {
          minDist = d;
          closestIndex = i;
        }
      }
      
      // 해당 다각형의 바이옴(Biome) 색상으로 픽셀 칠하기
      pixels[x + y * width] = points[closestIndex].c;
    }
  }
  
  updatePixels();
  
  // 다각형의 중심점 시각화 (원하지 않으면 이 부분 삭제)
  fill(0, 100);
  noStroke();
  for(int i = 0; i < NUM_POINTS; i++) {
    ellipse(points[i].x, points[i].y, 4, 4);
  }
}

// 중심점을 각 보로노이 셀의 무게중심으로 이동시키는 함수
void relaxPoints() {
  float[] sumX = new float[NUM_POINTS];
  float[] sumY = new float[NUM_POINTS];
  int[] count = new int[NUM_POINTS];
  
  for (int x = 0; x < width; x++) {
    for (int y = 0; y < height; y++) {
      int closestIndex = 0;
      float minDist = width * height;
      for (int i = 0; i < NUM_POINTS; i++) {
        float d = dist(x, y, points[i].x, points[i].y);
        if (d < minDist) {
          minDist = d;
          closestIndex = i;
        }
      }
      sumX[closestIndex] += x;
      sumY[closestIndex] += y;
      count[closestIndex]++;
    }
  }
  
  for (int i = 0; i < NUM_POINTS; i++) {
    if (count[i] > 0) {
      points[i].x = sumX[i] / count[i];
      points[i].y = sumY[i] / count[i];
    }
  }
}

// 각 셀에 고도와 수분을 부여하고 바이옴 색상을 결정하는 함수
void assignAttributes() {
  for (int i = 0; i < NUM_POINTS; i++) {
    Point p = points[i];
    
    // 섬(Island) 형태를 만들기 위해 중앙에서부터의 거리 계산
    float nx = p.x / width - 0.5;
    float ny = p.y / height - 0.5;
    float distance = sqrt(nx*nx + ny*ny) * 2.0; // 중앙은 0, 외곽은 최대 1.414
    
    // Perlin 노이즈를 더해 자연스러운 해안선과 고도 생성
    float elevationNoise = noise(p.x * 0.005, p.y * 0.005);
    p.elevation = 1.0 - distance + (elevationNoise * 0.6); 
    
    // Perlin 노이즈로 수분 맵 생성 (고도와 독립적인 좌표계 사용)
    p.moisture = noise(p.x * 0.01 + 100, p.y * 0.01 + 100);
    
    // 특성에 따라 바이옴 색상 매핑
    p.c = getBiomeColor(p.elevation, p.moisture);
  }
}

// 논문의 2D 매트릭스를 기반으로 한 바이옴(지형) 결정 함수
color getBiomeColor(float e, float m) {
  // 고도가 낮으면 무조건 물/해변
  if (e < 0.25) return color(44, 107, 155);       // 깊은 바다 (Ocean)
  if (e < 0.4)  return color(84, 147, 195);       // 얕은 바다 (Coast)
  if (e < 0.45) return color(210, 185, 139);      // 해변 (Beach)
  
  // 고도가 높을 때
  if (e > 0.9) {
    if (m > 0.5) return color(255, 255, 255);     // 눈 덮인 산 (Snow)
    else return color(136, 136, 136);             // 바위 산 (Bare)
  }
  
  // 고도가 중간일 때 수분에 따라 결정
  if (m < 0.33) return color(201, 210, 155);      // 사막/건조지대 (Desert)
  if (m < 0.66) return color(136, 170, 85);       // 초원/평야 (Grassland)
  return color(51, 119, 85);                      // 숲/밀림 (Forest)
}

// 셀 데이터를 담는 클래스
class Point {
  float x, y;
  float elevation;
  float moisture;
  color c;
  
  Point(float x, float y) {
    this.x = x;
    this.y = y;
  }
}
