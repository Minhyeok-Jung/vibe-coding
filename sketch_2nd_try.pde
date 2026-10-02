int NUM_POINTS = 300;
Point[] points = new Point[NUM_POINTS];

// 각 픽셀이 어떤 다각형에 속하는지 저장 (렌더링 최적화)
int[][] cellMap;
// 두 다각형(셀)이 서로 인접해 있는지 저장하는 그래프
boolean[][] neighbors;

// 강이 흐르는 경로(선)를 저장
ArrayList<RiverEdge> riverEdges = new ArrayList<RiverEdge>();

void setup() {
  size(800, 800);
  noLoop(); 
  
  cellMap = new int[width][height];
  neighbors = new boolean[NUM_POINTS][NUM_POINTS];
  
  println("1/5: 포인트 무작위 생성 중...");
  for (int i = 0; i < NUM_POINTS; i++) {
    points[i] = new Point(random(width), random(height));
  }
  
  println("2/5: 로이드 이완(Lloyd Relaxation) 적용 중...");
  for (int i = 0; i < 3; i++) {
    relaxPoints();
  }
  
  println("3/5: 이웃(Neighbor) 그래프 생성 및 고도/수분 할당...");
  buildGraph();
  assignAttributes();
  
  println("4/5: 강(Rivers) 생성 중...");
  generateRivers();
  
  // 강 생성 후 수분이 변경되었으므로 바이옴 색상 최종 업데이트
  for (int i = 0; i < NUM_POINTS; i++) {
    points[i].updateColor();
  }
  
  println("5/5: 렌더링 완료!");
}

void draw() {
  background(0);
  loadPixels();
  
  // 1. 다각형(바이옴) 그리기 (cellMap을 이용해 매우 빠르게 렌더링)
  for (int x = 0; x < width; x++) {
    for (int y = 0; y < height; y++) {
      pixels[x + y * width] = points[cellMap[x][y]].c;
    }
  }
  updatePixels();
  
  // 2. 강(Rivers) 그리기
  stroke(44, 107, 155); // 물(River) 색상
  strokeWeight(3);
  for (RiverEdge edge : riverEdges) {
    Point p1 = points[edge.from];
    Point p2 = points[edge.to];
    line(p1.x, p1.y, p2.x, p2.y);
  }
  
  /* 다각형 중심점을 보고 싶다면 아래 주석을 해제하세요.
  fill(0, 100); noStroke();
  for(int i = 0; i < NUM_POINTS; i++) ellipse(points[i].x, points[i].y, 4, 4);
  */
}

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

// 픽셀 맵을 순회하며 어떤 다각형들이 서로 맞닿아 있는지(Neighbors) 기록합니다.
void buildGraph() {
  // 1. 모든 픽셀에 대해 가장 가까운 중심점(Cell) 찾기
  for (int x = 0; x < width; x++) {
    for (int y = 0; y < height; y++) {
      int closest = 0;
      float minDist = width * height;
      for (int i = 0; i < NUM_POINTS; i++) {
        float d = dist(x, y, points[i].x, points[i].y);
        if (d < minDist) {
          minDist = d;
          closest = i;
        }
      }
      cellMap[x][y] = closest;
    }
  }
  
  // 2. 인접한 픽셀의 주인이 다르면 두 다각형은 이웃(Neighbor)입니다.
  for (int x = 0; x < width - 1; x++) {
    for (int y = 0; y < height - 1; y++) {
      int c1 = cellMap[x][y];
      int c2 = cellMap[x+1][y];
      int c3 = cellMap[x][y+1];
      
      if (c1 != c2) { neighbors[c1][c2] = true; neighbors[c2][c1] = true; }
      if (c1 != c3) { neighbors[c1][c3] = true; neighbors[c3][c1] = true; }
    }
  }
}

void assignAttributes() {
  for (int i = 0; i < NUM_POINTS; i++) {
    Point p = points[i];
    float nx = p.x / width - 0.5;
    float ny = p.y / height - 0.5;
    float distance = sqrt(nx*nx + ny*ny) * 2.0; 
    
    float elevationNoise = noise(p.x * 0.005, p.y * 0.005);
    p.elevation = 1.0 - distance + (elevationNoise * 0.6); 
    p.moisture = noise(p.x * 0.01 + 100, p.y * 0.01 + 100);
  }
}

// 고도(Elevation)를 따라 바다로 흐르는 강을 생성합니다.
void generateRivers() {
  int numRiversToSpawn = 20; // 생성할 강의 개수
  
  for (int i = 0; i < numRiversToSpawn; i++) {
    int current = (int)random(NUM_POINTS);
    
    // 강은 오직 산맥이나 고지대에서만 시작합니다.
    if (points[current].elevation < 0.6) continue;
    
    while (true) {
      // 바다(Coast/Ocean)에 도달하면 흐름을 멈춥니다.
      if (points[current].elevation < 0.4) break; 
      
      // 이웃들 중 가장 고도가 낮은 곳을 찾습니다. (Downhill)
      int nextCell = -1;
      float minElevation = points[current].elevation;
      
      for (int n = 0; n < NUM_POINTS; n++) {
        if (neighbors[current][n] && points[n].elevation < minElevation) {
          minElevation = points[n].elevation;
          nextCell = n;
        }
      }
      
      // 더 이상 내려갈 곳이 없다면 웅덩이(Pit)에 갇힌 것입니다. 호수가 됩니다.
      if (nextCell == -1) {
        points[current].isLake = true;
        break;
      }
      
      // 강이 흐르는 길을 리스트에 저장하고, 지나간 땅에 수분을 더해줍니다.
      riverEdges.add(new RiverEdge(current, nextCell));
      points[current].moisture += 0.3; // 강 주변은 수분이 높아져 숲이 될 확률이 올라감
      
      current = nextCell;
    }
  }
}

class RiverEdge {
  int from, to;
  RiverEdge(int from, int to) {
    this.from = from;
    this.to = to;
  }
}

class Point {
  float x, y;
  float elevation;
  float moisture;
  boolean isLake = false;
  color c;
  
  Point(float x, float y) {
    this.x = x;
    this.y = y;
  }
  
  // 고도와 수분을 바탕으로 최종 색상 갱신
  void updateColor() {
    if (isLake) {
      c = color(84, 147, 195); // 호수 색상 (얕은 바다와 동일)
      return;
    }
    
    if (elevation < 0.25) c = color(44, 107, 155);       // 깊은 바다
    else if (elevation < 0.4)  c = color(84, 147, 195);  // 얕은 바다
    else if (elevation < 0.45) c = color(210, 185, 139); // 해변
    else if (elevation > 0.9) {
      if (moisture > 0.5) c = color(255, 255, 255);      // 눈 덮인 산
      else c = color(136, 136, 136);                     // 바위 산
    }
    else {
      if (moisture < 0.33) c = color(201, 210, 155);     // 사막
      else if (moisture < 0.66) c = color(136, 170, 85); // 초원
      else c = color(51, 119, 85);                       // 숲
    }
  }
}
