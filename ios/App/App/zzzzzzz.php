async function toggleSpeechRecognition() {
    const micBtn = document.getElementById('micBtn');
    const textarea = document.getElementById('passScheduleInput');

    // 1. Kiểm tra môi trường Capacitor Native
    const isCapacitorNative = window.Capacitor && window.Capacitor.isNativePlatform();

    function stopRecordingUI() {
        isRecording = false;
        if (micBtn) micBtn.classList.remove('mic-recording');
    }

    function startRecordingUI() {
        isRecording = true;
        if (micBtn) micBtn.classList.add('mic-recording');
    }

    function appendText(text) {
        textarea.value = baseText + text;
        if (typeof toggleClearBtnVisibility === 'function') {
            toggleClearBtnVisibility(textarea);
        }
        textarea.scrollTop = textarea.scrollHeight;
    }

    // Lấy văn bản đang có sẵn
    baseText = textarea.value;
    if (baseText.length > 0 && !baseText.endsWith(' ')) {
        baseText += ' ';
    }

    // ==========================================
    // TRƯỜNG HỢP 1: CHẠY TRÊN CAPACITOR APP (NATIVE)
    // ==========================================
    if (isCapacitorNative) {
        const { SpeechRecognition } = window.Capacitor.Plugins;

        if (!SpeechRecognition) {
            alert('Chưa cài đặt plugin SpeechRecognition trên App!');
            return;
        }

        // Nếu đang ghi âm -> Dừng lại
        if (isRecording) {
            await SpeechRecognition.stop();
            stopRecordingUI();
            return;
        }

        try {
            // Kiểm tra và xin quyền
            const hasPermission = await SpeechRecognition.hasPermission();
            if (!hasPermission.permission) {
                const req = await SpeechRecognition.requestPermission();
                if (!req.permission) {
                    alert('Vui lòng cấp quyền Micro và Speech Recognition trong Cài đặt!');
                    return;
                }
            }

            startRecordingUI();

            // Đăng ký lắng nghe sự kiện trả về dữ liệu nhận diện
            SpeechRecognition.removeAllListeners();
            SpeechRecognition.addListener('partialResults', (data) => {
                if (data.matches && data.matches.length > 0) {
                    appendText(data.matches[0]);
                }
            });

            // Bắt đầu nhận diện giọng nói
            await SpeechRecognition.start({
                language: 'vi-VN',
                maxResults: 2,
                prompt: 'Hãy nói yêu cầu đặt xe...',
                partialResults: true,
                popup: false
            });

        } catch (error) {
            console.error('Lỗi Native Speech Recognition:', error);
            stopRecordingUI();
        }
        return;
    }

    // ==========================================
    // TRƯỜNG HỢP 2: CHẠY TRÊN TRÌNH DUYỆT WEB (WEB API)
    // ==========================================
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;

    if (!SpeechRecognition) {
        alert('Trình duyệt của bạn không hỗ trợ Micro voice. Hãy dùng Chrome hoặc Safari mới nhất!');
        return;
    }

    if (isRecording) {
        if (recognition) recognition.stop();
        stopRecordingUI();
        return;
    }

    try {
        recognition = new SpeechRecognition();
        recognition.lang = 'vi-VN';
        recognition.continuous = true;
        recognition.interimResults = true;

        recognition.onstart = function() {
            startRecordingUI();
        };

        recognition.onresult = function(event) {
            let interimTranscript = '';
            let finalTranscript = '';

            for (let i = event.resultIndex; i < event.results.length; ++i) {
                if (event.results[i].isFinal) {
                    finalTranscript += event.results[i][0].transcript;
                } else {
                    interimTranscript += event.results[i][0].transcript;
                }
            }

            appendText(finalTranscript + interimTranscript);
        };

        recognition.onerror = function(event) {
            console.warn('Speech recognition error:', event.error);
            stopRecordingUI();
        };

        recognition.onend = function() {
            stopRecordingUI();
        };

        recognition.start();

    } catch (e) {
        console.error(e);
        stopRecordingUI();
    }
}
