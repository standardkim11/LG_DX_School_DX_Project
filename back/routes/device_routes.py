from flask import Blueprint, jsonify, request
from datetime import datetime
import threading
import time

device_bp = Blueprint("device", __name__)

# 세탁기 시작 명령 상태 저장 (간단한 메모리 기반)
washing_machine_start_command = {
    "pending": False,
    "timestamp": None,
}

# 스레드 안전을 위한 락
lock = threading.Lock()


@device_bp.route("/device/start-washing-machine", methods=["POST", "OPTIONS"])
def start_washing_machine():
    """세탁기 시작 명령을 설정"""
    # OPTIONS 요청 처리 (CORS preflight)
    if request.method == "OPTIONS":
        response = jsonify({})
        # app.py의 after_request에서 이미 CORS 헤더를 추가하므로 여기서는 추가하지 않음
        return response
    
    global washing_machine_start_command
    
    with lock:
        washing_machine_start_command["pending"] = True
        washing_machine_start_command["timestamp"] = datetime.now().isoformat()
        pending_status = washing_machine_start_command["pending"]
    
    print(f"[DeviceRoutes] ✅ 세탁기 시작 명령 수신: {washing_machine_start_command['timestamp']}")
    print(f"[DeviceRoutes] pending 상태: {pending_status}")
    
    # app.py의 after_request에서 이미 CORS 헤더를 추가하므로 여기서는 추가하지 않음
    return jsonify({
        "success": True,
        "message": "세탁기 시작 명령이 전송되었습니다.",
    })


@device_bp.route("/device/test", methods=["GET"])
def test_device():
    """테스트용 엔드포인트"""
    # app.py의 after_request에서 이미 CORS 헤더를 추가하므로 여기서는 추가하지 않음
    return jsonify({
        "status": "ok",
        "message": "Device API is working",
    })


@device_bp.route("/device/check-washing-machine-command", methods=["GET", "OPTIONS"])
def check_washing_machine_command():
    """세탁기 시작 명령이 있는지 확인 (브라우저가 폴링)"""
    # OPTIONS 요청 처리 (CORS preflight)
    if request.method == "OPTIONS":
        response = jsonify({})
        # app.py의 after_request에서 이미 CORS 헤더를 추가하므로 여기서는 추가하지 않음
        return response
    
    global washing_machine_start_command
    
    with lock:
        pending_status = washing_machine_start_command["pending"]
        print(f"[DeviceRoutes] [폴링 요청] pending 상태 확인: {pending_status}")
        
        if pending_status:
            # 명령을 확인했으므로 pending 상태 해제
            should_start = True
            timestamp = washing_machine_start_command["timestamp"]
            washing_machine_start_command["pending"] = False
            print(f"[DeviceRoutes] ✅ 세탁기 시작 명령 확인됨 (브라우저): {timestamp}")
            print(f"[DeviceRoutes] pending 상태를 False로 변경")
            # app.py의 after_request에서 이미 CORS 헤더를 추가하므로 여기서는 추가하지 않음
            return jsonify({
                "should_start": True,
                "timestamp": timestamp,
            })
        else:
            # app.py의 after_request에서 이미 CORS 헤더를 추가하므로 여기서는 추가하지 않음
            return jsonify({
                "should_start": False,
            })

