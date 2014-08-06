import com.heroicrobot.dropbit.registry.*;
import com.heroicrobot.dropbit.devices.pixelpusher.Pixel;
import com.heroicrobot.dropbit.devices.pixelpusher.Strip;
import com.heroicrobot.dropbit.devices.pixelpusher.PixelPusher;
import java.util.*;

import de.looksgood.ani.*;
import de.looksgood.ani.easing.*;
import g4p_controls.*;

import java.net.URI;
import java.net.URISyntaxException;

import org.java_websocket.client.WebSocketClient;
import org.java_websocket.drafts.*;
import org.java_websocket.handshake.ServerHandshake;

PImage texture;
Ring rings[];
float smoothX, smoothY;
boolean f = false;
float intensity;
float ringSpeed;
int pulseSpeed;
int pulseBreak;
int lastPulse;
boolean secondBeat;
GSlider pulseSlider;
GSlider speedSlider;
GSlider ringNumSlider;

int oWidth;
int oHeight;

private WebSocketClient cc;
JSONObject data;

PVector selectedPoint = null;
ArrayList<Segment> segments;

DeviceRegistry registry;
TestObserver testObserver;
 
void setup()
{
  oWidth = displayWidth;
  oHeight = displayHeight;
  // size(displayWidth, displayHeight, P3D);
  size(oWidth, oHeight, P3D);
  colorMode(HSB, 100);
  texture = loadImage("ring.png");
  ringSpeed = 3.0;
  pulseSpeed = 2500;
  pulseBreak = int(pulseSpeed * .2);
  Ani.init(this);
  lastPulse = millis();
  secondBeat = false;
  
  registry = new DeviceRegistry();
  testObserver = new TestObserver();
  registry.addObserver(testObserver);
 
  segments = new ArrayList<Segment>();

  rings = new Ring[10];
  for (int i = 0; i < rings.length; i++) {
    rings[i] = new Ring(random(0, width), random(0, height), random(0, width), random(0, height));
    rings[i].draw();
  }
  
//  pulseSlider = new GSlider(this, width - 100, height - 30, 100, 30, 15);
//  speedSlider = new GSlider(this, width - 200, height - 30, 100, 30, 15);
//  ringNumSlider = new GSlider(this, width - 300, height - 30, 100, 30, 15);
  
  
}

void pulse() {
  intensity = 100.0;
  int max = oWidth;
  if (max < oHeight) {
    max = oHeight;
  }
  Ani.to(this, pulseSpeed / max * 4, "intensity", 0);
  for (int i = 0; i < rings.length; i++) {
    if (!secondBeat) {
//      rings[i].seek(random(0, width), random(0, height), random(0, width), random(0, height));
    } else {
      rings[i].reset(random(0, width), random(0, height), random(0, width), random(0, height));
    }
  }
}
 
void draw()
{
  background(0);
  for (int i = 0; i < rings.length; i++) {
    rings[i].draw();
  }
  
  if (lastPulse < millis()) {
    if (secondBeat) {
      lastPulse = millis() + pulseSpeed;
    } else {
      lastPulse = millis() + pulseBreak;
    }
    secondBeat = !secondBeat;
    pulse();
  }
  
//  updatePixels();
  ellipseMode(CENTER);
  if (testObserver.hasStrips) {
    
    registry.setExtraDelay(0);
    registry.startPushing();
  
    for(Segment seg : segments){
      seg.samplePixels();
    }
  
    for(Segment seg : segments){
      seg.draw();
    }      
  }
  
}

class Ring
{
  float x, y, size, hue, seekX, seekY, newX, newY;
  
  Ring(float x1, float y1, float x2, float y2) {
    //reset(x1, x2);
    seek(x2, y2);
    size = oWidth * .8;
  }
  
  void reset(float x1, float y1, float x2, float y2) {
    x = x1;
    y = y1;
    Ani.to(this, ringSpeed, "x", x2, Ani.LINEAR);
    Ani.to(this, ringSpeed, "y", y2, Ani.LINEAR);
    hue = random(0, 100);
  }
  
  void seek(float x1, float y1) {
    
  }
 
  void draw()
  {
    blendMode(ADD);
    tint(hue, 50, intensity);
    image(texture, x - size/2, y - size/2, size, size);
  }
};

public void handleSliderEvents(GValueControl slider, GEvent event) { 
  if (slider == pulseSlider) {
    pulseSpeed = int(2500 * float(pulseSlider.getValueS()) + 500);
    pulseBreak = int(pulseSpeed / 5);
    lastPulse = millis();
  } else if (slider == speedSlider) {
    ringSpeed = 1 + float(speedSlider.getValueS()) * 4;
  } else if (slider == ringNumSlider) {
    rings = new Ring[int(float(ringNumSlider.getValueS()) * 25) + 1];
    for (int i = 0; i < rings.length; i++) {
      rings[i] = new Ring(random(0, width), random(0, height), random(0, width), random(0, height));
      rings[i].draw();
    }
  }
}

class TestObserver implements Observer {
  public boolean hasStrips = false;
  public void update(Observable reg, Object updatedDevice) {

    if(!this.hasStrips){
      PixelPusher pusher = (PixelPusher)updatedDevice;
      List<Strip> strips = pusher.getStrips();

      // add segments for any strips that have been discovered.
      for(int i = 0; i < 6; i++){
        segments.add( new Segment(i * 60 + 60, 20, i * 60 + 60, 480, strips.get(i)) );
      } 

      this.hasStrips = true;
    }
  }
};

class Segment{
  
  PVector sampleStart;
  PVector sampleStop;
  Strip strip;
  int pixelOffset = 0;
  int pixelCount = 0;
  
  Segment(float startX, float startY, float stopX, float stopY, Strip strip, int pixelCount, int pixelOffset ){
    this( startX, startY, stopX, stopY, strip );
    this.pixelCount = pixelCount;
    this.pixelOffset = pixelOffset;
  }
  
  Segment(float startX, float startY, float stopX, float stopY, Strip strip ){
    this.sampleStart = new PVector(startX, startY);
    this.sampleStop = new PVector(stopX, stopY);
    this.strip = strip;
    this.pixelCount = strip.getLength();
    println("Pixels!!! : " + this.pixelCount);
  }
  
  // draw end points and sample points.
  public void draw() {
    stroke(255, 1, 1);
//    noFill();
    fill(255);
    
    // draw circles at the end points.
    ellipse(this.sampleStart.x, this.sampleStart.y, 8,8);
    ellipse(this.sampleStop.x, this.sampleStop.y, 8,8);
    
    PVector step = PVector.sub(this.sampleStop, this.sampleStart);
    step.div( this.pixelCount ); 
   
    PVector samplePos = new PVector();
    samplePos.set(this.sampleStart);

//    noStroke();
    for(int i = 0; i < pixelCount; i++){
      fill(127, 100);
      ellipse(samplePos.x, samplePos.y, 3.5, 3.5);
      samplePos.add( step );
    }
  } 
  
  // sample pixels and push them to a strip.
  public void samplePixels() {
    
    PVector step = PVector.sub(this.sampleStop, this.sampleStart);
    step.div( this.pixelCount ); 
     
    PVector samplePos = new PVector();
    samplePos.set(this.sampleStart);
     
    for(int i = 0; i < this.pixelCount; i++) {
      this.strip.setPixel(get((int)samplePos.x, (int)samplePos.y), i + this.pixelOffset);
      samplePos.add(step);
    }     
  }
}

void mousePressed() {
  PVector mouse = new PVector(mouseX, mouseY);
  selectedPoint = null;
  
  for(Segment seg : segments){
    if(seg.sampleStart.dist(mouse) < 12){
      selectedPoint = seg.sampleStart;
      break;
    }else if(seg.sampleStop.dist(mouse) < 12){
      selectedPoint = seg.sampleStop;
      break;
    }
  }
}

void mouseDragged(){
  if(selectedPoint != null){
    selectedPoint.x = mouseX;
    selectedPoint.y = mouseY;
  }
}
