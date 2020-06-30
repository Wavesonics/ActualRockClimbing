extends Spatial

var grab_area : Area = null;
var controller : ARVRController = null;

# if true the body is checked if it has a method "oq_can_static_grab" and calls it
# to check if it actually can be grabbed. All other objects are ignored
export var check_parent_can_static_grab = false;

signal oq_static_grab_started;
signal oq_static_grab_ended;

var is_grabbing = false;
var is_just_grabbing = false;
var grabbed_object = null;
var grab_position = Vector3();
var delta_position = Vector3();

const GRAB_GESTURE := "Fist"
var last_gesture

var _additional_grab_checker = null;

export(vr.CONTROLLER_BUTTON) var grab_button = vr.CONTROLLER_BUTTON.GRIP_TRIGGER;

func _ready():
	controller = get_parent();
	if (not controller is ARVRController):
		vr.log_error(" in Feature_StaticGrab: parent not ARVRController.");
	grab_area = $GrabArea;


func just_gripped() -> bool:
	var did_grip: bool
	
	var hand = controller.get_hand_model();
	if hand:
		var cur_gesture = hand.detect_simple_gesture()
		if cur_gesture != last_gesture and cur_gesture == GRAB_GESTURE:
			print("HAND: did just grab")
			did_grip = true
		last_gesture = cur_gesture
	else:
		did_grip = controller._button_just_pressed(grab_button)
	
	return did_grip


func not_grabbing() -> bool:
	var not_grabbed: bool
	
	var hand = controller.get_hand_model();
	if hand:
		last_gesture = hand.detect_simple_gesture()
		not_grabbed = last_gesture != GRAB_GESTURE
	else:
		not_grabbed = !controller._button_pressed(grab_button)
	
	return not_grabbed

	
func _physics_process(_dt):
	grab_area.global_transform = controller.get_palm_transform();

	if (just_gripped()):
		if (_additional_grab_checker):
			grabbed_object = _additional_grab_checker.oq_additional_static_grab_check(grab_area, controller);

		var overlapping_bodies = grab_area.get_overlapping_bodies();
		for b in overlapping_bodies:
			if (check_parent_can_static_grab):
				var p = b.get_parent();
				if (p && p.has_method("oq_can_static_grab")):
					if (!p.oq_can_static_grab(b, grab_area, controller, overlapping_bodies)): continue;
				else:
					continue;
			
			grabbed_object = b;
			break;

		if (grabbed_object):
			is_grabbing = true;
			is_just_grabbing = true;
			grab_position = controller.translation; # we need the local translation here as we will move the origin
			emit_signal("oq_static_grab_started", grabbed_object, controller)

	else:
		is_just_grabbing = false;
	
	if (not_grabbing()):
		if (is_grabbing):
			emit_signal("oq_static_grab_ended", grabbed_object, controller)
			grabbed_object = null;
			is_grabbing = false;
	elif (is_grabbing):
		delta_position = vr.vrOrigin.global_transform.basis.xform(controller.translation - grab_position);


