extends Node2D


const trailLength = 10
const trailWidth = 2

class point:
	var position: Vector2
	var positionPixels: Vector2 #position multiplied by screen dimensions, one of the axis will be squashed unless the canvas is square
	var velocity: Vector2
	var color: Color
	var trailPoints: PoolVector2Array 
	
	#Constructor of the point class
	func _init(positionPixels:Vector2,screenDimensions:Vector2):
		self.position = positionPixels / screenDimensions 
		self.positionPixels = positionPixels
		self.color = Color(randf(),randf(),randf(),1)
		self.trailPoints = PoolVector2Array()
		self.trailPoints.resize(trailLength)
		self.trailPoints.fill(positionPixels)
		self.velocity = Vector2(0,0)
		
		
var sparkImage
const maxVelocity = 2
const constSize = 64.0
const variableSize = 24.0

#Each vector in this array corresponds to a corner of a wall. First wall's corners are wall[0] and wall[1]
var walls = []
var constantPoints = []
var variablePoints = []

var screenX
var screenY

# Called when the node enters the scene tree for the first time.
func _ready():
	sparkImage = preload("res://icon.png")
	get_tree().get_root().connect("size_changed", self, "windowResized")
	windowResized()
	Engine.set_target_fps(60)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
var frame = 0
func _process(delta):
	
	frame += 1
	
	for x in variablePoints:
		
		for y in constantPoints:
			var distanceVec = Vector2(x.position.x-y.position.x,x.position.y-y.position.y)
			if abs(distanceVec.x) < 0.01 && abs(distanceVec.y) < 0.01:
				#We don't want to apply force if it is too close
				continue
			var distanceRaw = pow(distanceVec.x,2) + pow(distanceVec.y,2)
			var distance = sqrt(distanceRaw)
			
			x.velocity += Vector2(-1/distance*(distanceVec.x/distance),-1/distance*(distanceVec.y/distance))/100
			#Different from the real equation. To make it more insteresting to look at
		
		x.velocity = x.velocity.limit_length(maxVelocity)
		
		bouncePoint(x,-1,0,delta) #Also handles moving the point
		
		x.positionPixels = x.position * Vector2(screenX,screenY)
		
		for i in trailLength:
			#Move every member one index back
			x.trailPoints[trailLength -1 -i] = x.trailPoints[trailLength -2 -i]
			
		x.trailPoints[0] = x.positionPixels
		
	if $fps.visible:
		$fps.text = str(int(1/delta))
		
	update() # calls the _draw function
	
func bouncePoint(pt:point,lastWall:int,recursionDepth,delta):
	
	#Still not perfect, but A LOT better than the last one i had
	
	if recursionDepth > 9:
		pt.velocity = Vector2(0,0)
		return
	
	var closestIntLoc #Vec2 of where the closest intersection occurs
	var closestIntLength = 1000.0 #Length between the point and closest intersection
	var closestIntWall #ID of the said intersection
	
	for w in len(walls)/2:
		
		if w == lastWall:
			continue
			
		var intResult = getLineIntersection(pt.position,pt.position+pt.velocity*delta,walls[w*2],walls[w*2+1])
		if typeof(intResult) == TYPE_VECTOR2:
			
			var distance = (pt.position - intResult).length()
			if distance < closestIntLength:
				closestIntLoc = intResult
				closestIntLength = distance
				closestIntWall = w
				
	if typeof(closestIntLoc) == TYPE_VECTOR2:
		var wallNormal = walls[closestIntWall*2].direction_to(walls[closestIntWall*2+1]).tangent()
		pt.velocity = pt.velocity.bounce(wallNormal) *95/100
		pt.position = closestIntLoc
		bouncePoint(pt,closestIntWall,recursionDepth+1,delta)

	else:
		pt.position += pt.velocity * delta
		return

func _draw():
	for x in constantPoints:
		var tempVec = Vector2(constSize,constSize)
		draw_texture_rect(sparkImage,Rect2(x.positionPixels-tempVec/2,tempVec),false,x.color*8/10 + x.color*(sin(frame/100.0) + 1)/10) # It's brightness will oscillate
		
	for x in variablePoints:
		var tempVec = Vector2(variableSize,variableSize)
		draw_texture_rect(sparkImage,Rect2(x.positionPixels-tempVec/2,tempVec),false,x.color*8/10)
		draw_line(x.positionPixels,x.positionPixels+x.velocity*1000/60,Color(1,1,1,1),2) #Draw trajectory (for 60fps)
		draw_polyline(x.trailPoints,x.color,trailWidth,true) #Draw trail
		
	for x in len(walls)/2:
		draw_line(walls[x*2]*Vector2(screenX,screenY),walls[x*2+1]*Vector2(screenX,screenY),Color(1,1,1,1),2)
		
func windowResized():
	screenX = get_viewport().get_visible_rect().size.x
	screenY = get_viewport().get_visible_rect().size.y
	
	for x in constantPoints:
		x.positionPixels = x.position * Vector2(screenX,screenY)
	
	$Background.texture.width = screenX
	$Background.texture.height = screenY

var pressLocation:Vector2 #starting point of wall

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT && event.pressed:
			var temp = point.new(event.position , Vector2(screenX,screenY))
			variablePoints.append(temp)
			
		if event.button_index == BUTTON_RIGHT:
			if event.pressed:
				pressLocation = event.position
			
			elif !event.pressed:
				if abs(event.position.x - pressLocation.x) < 10 && abs(event.position.y - pressLocation.y) < 10:
					#If the mouse hasn't moved while pressed down, create a constant point
					var temp = point.new(event.position , Vector2(screenX,screenY))
					constantPoints.append(temp)
				else:
					#If the mouse has moved, then create a wall
					walls.append(pressLocation/Vector2(screenX,screenY))
					walls.append(event.position/Vector2(screenX,screenY))
	elif event is InputEventKey:
		if event.scancode == KEY_F:
			if event.pressed:
				if $fps.visible:
					$fps.hide()
				else:
					$fps.show()

func getLineIntersection(p0:Vector2,p1:Vector2,p2:Vector2,p3:Vector2):

	var intersection:Vector2
	
	var s1 = Vector2(p1.x - p0.x,p1.y - p0.y)
	var s2 = Vector2(p3.x - p2.x,p3.y - p2.y)

	var s:float
	var t:float
	
	if (-s2.x * s1.y + s1.x * s2.y) == 0 || (-s2.x * s1.y + s1.x * s2.y) == 0:
		#division by zero
		return
	
	s = (-s1.y * (p0.x - p2.x) + s1.x * (p0.y - p2.y)) / (-s2.x * s1.y + s1.x * s2.y);
	t = ( s2.x * (p0.y - p2.y) - s2.y * (p0.x - p2.x)) / (-s2.x * s1.y + s1.x * s2.y);

	if (s >= 0 && s <= 1 && t >= 0 && t <= 1):
		
		intersection = Vector2(p0.x + (t * s1.x),p0.y + (t * s1.y))
		return intersection #Return the coordinates of collision
	
	return #No collision

func _on_TutorialTimer_timeout():
	#Hide the tutorial after 12 seconds
	$Tutorial.hide()
	pass
