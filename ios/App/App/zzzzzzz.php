// --- TÍCH HỢP TỰ ĐỘNG KHÔNG GIAN SPEECH RECOGNITION (VOICE TO TEXT) ---
btnMic.addEventListener(\'click\', async () => {
    // 1. Kiểm tra môi trường Capacitor Native
    const isCapacitorNative = window.Capacitor && window.Capacitor.isNativePlatform();

    const stopRecordingUI = () => {
        isRecording = false;
        btnMic.classList.remove(\'recording\');
        msgInput.focus();
    };

    const startRecordingUI = () => {
        isRecording = true;
        btnMic.classList.add(\'recording\');
    };

    // ==========================================
    // KỊCH BẢN A: CHẠY TRÊN CAPACITOR APP (NATIVE)
    // ==========================================
    if (isCapacitorNative) {
        const { SpeechRecognition } = window.Capacitor.Plugins;

        if (!SpeechRecognition) {
            return alert(\'Chưa đăng ký plugin SpeechRecognition trên Native!\');
        }

        // 🛑 NẾU ĐANG GHI ÂM -> BẤM LẦN 2 ĐỂ TẮT
        if (isRecording) {
            try {
                await SpeechRecognition.stop();
            } catch (e) {
                console.error(\'Lỗi khi dừng Native Mic:\', e);
            }
            stopRecordingUI();
            console.log("🛑 Đã chủ động kết thúc tiến trình ghi âm Native.");
            return;
        }

        // 🎤 NẾU ĐANG RẢNH -> BẤM ĐỂ BẮT ĐẦU GHI ÂM
        try {
            // Kiểm tra và xin quyền Native iOS/Android
            const hasPermission = await SpeechRecognition.hasPermission();
            if (!hasPermission.permission) {
                const req = await SpeechRecognition.requestPermission();
                if (!req.permission) {
                    return alert(\'Vui lòng cấp quyền Micro và Speech Recognition trong Cài đặt!\');
                }
            }

            startRecordingUI();
            console.log("🎤 Hệ thống Native bắt đầu lắng nghe giọng nói...");

            // Lắng nghe dữ liệu trả về real-time
            SpeechRecognition.removeAllListeners();
            SpeechRecognition.addListener(\'partialResults\', (data) => {
                if (data.matches && data.matches.length > 0) {
                    msgInput.value = data.matches[0];
                }
            });

            // Kích hoạt ghi âm
            await SpeechRecognition.start({
                language: \'vi-VN\',
                maxResults: 1,
                prompt: \'Hãy nói nội dung tin nhắn...\',
                partialResults: true,
                popup: false
            });

        } catch (err) {
            console.error(\'Lỗi khởi tạo Native Speech Recognition:\', err);
            stopRecordingUI();
        }
        return;
    }

    // ==========================================
    // KỊCH BẢN B: CHẠY TRÊN TRÌNH DUYỆT WEB (WEB API)
    // ==========================================
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) return alert(\'Trình duyệt của bạn chưa hỗ trợ Voice to Text. Hãy dùng Google Chrome!\');

    // KỊCH BẢN 1: NẾU ĐANG GHI ÂM -> BẤM LẦN 2 ĐỂ ÉP KẾT THÚC TIẾN TRÌNH VÀ GIỮ CHỮ
    if (isRecording) {
        if (recognition) {
            recognition.stop(); 
        }
        stopRecordingUI();
        console.log("🛑 Đã chủ động kết thúc tiến trình ghi âm Web.");
        return;
    }

    // KỊCH BẢN 2: NẾU ĐANG RẢNH -> BẤM ĐỂ BẮT ĐẦU GHI ÂM
    recognition = new SpeechRecognition();
    recognition.lang = \'vi-VN\';
    recognition.interimResults = true; 
    recognition.maxAlternatives = 1;

    let finalTranscript = \'\';

    try {
        recognition.start();
        startRecordingUI();
        console.log("🎤 Hệ thống Web bắt đầu lắng nghe giọng nói...");
    } catch (err) {
        console.error(\'Không thể kích hoạt phần cứng Mic:\', err);
    }

    // 🌟 XỬ LÝ NHẬN DIỆN THÔNG MINH REAL-TIME
    recognition.onresult = (event) => {
        let interimTranscript = \'\';

        for (let i = event.resultIndex; i < event.results.length; ++i) {
            if (event.results[i].isFinal) {
                finalTranscript += event.results[i][0].transcript;
            } else {
                interimTranscript += event.results[i][0].transcript;
            }
        }

        msgInput.value = finalTranscript || interimTranscript;
    };

    // Bắt lỗi hệ thống
    recognition.onerror = (err) => {
        console.log(\'Hệ thống Mic gặp thông báo:\', err.error);
    };

    // Khi tiến trình kết thúc
    recognition.onend = () => {
        stopRecordingUI();
        console.log("🔄 Tiến trình ghi âm đã được giải phóng sạch sẽ.");
    };
});
