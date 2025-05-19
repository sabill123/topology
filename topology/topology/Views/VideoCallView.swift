import SwiftUI
import AVFoundation

// 비디오 통화 화면
struct VideoCallView: View {
    let friend: Friend
    @State private var isCameraOn = true
    @State private var isMicOn = true
    @State private var isFlipped = false
    @State private var showDisconnectAlert = false
    @State private var showMoreOptions = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VideoCallSessionView(
            partner: friend,
            isCameraOn: $isCameraOn,
            isMicOn: $isMicOn,
            isFlipped: $isFlipped,
            onDisconnect: {
                presentationMode.wrappedValue.dismiss()
            }
        )
        .navigationBarHidden(true)
    }
}

// 화상 통화 세션 화면
struct VideoCallSessionView: View {
    let partner: Friend
    @Binding var isCameraOn: Bool
    @Binding var isMicOn: Bool
    @Binding var isFlipped: Bool
    var onDisconnect: () -> Void
    
    @State private var elapsedSeconds = 0
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var showDisconnectAlert = false
    @State private var showMoreOptions = false
    @State private var showFilterView = false
    @State private var currentFilter: String? = nil
    
    var body: some View {
        ZStack {
            // 상대방 비디오
            Color.black.ignoresSafeArea()
                .overlay(
                    VStack {
                        Text("👤")
                            .font(.system(size: 100))
                            .foregroundColor(.white.opacity(0.5))
                        Text(partner.name)
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("\(partner.age)세 • \(partner.country)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                )
            
            VStack {
                // 상단 정보
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(partner.name)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("\(partner.age)세 • \(partner.country)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    Text(formattedElapsedTime)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                }
                .padding()
                
                Spacer()
                
                // 내 비디오 (PIP)
                MyVideoPreview(isCameraOn: $isCameraOn, isFlipped: $isFlipped, currentFilter: $currentFilter)
                    .padding()
                
                // 통화 컨트롤
                CallControlButtons(
                    isMicOn: $isMicOn,
                    isCameraOn: $isCameraOn,
                    showDisconnectAlert: $showDisconnectAlert,
                    showMoreOptions: $showMoreOptions
                )
                .padding(.bottom, 30)
            }
        }
        .statusBar(hidden: true)
        .navigationBarHidden(true)
        .onReceive(timer) { _ in
            elapsedSeconds += 1
        }
        .alert(isPresented: $showDisconnectAlert) {
            Alert(
                title: Text("통화 종료"),
                message: Text("정말 통화를 종료하시겠습니까?"),
                primaryButton: .destructive(Text("종료")) {
                    onDisconnect()
                },
                secondaryButton: .cancel(Text("취소"))
            )
        }
        .actionSheet(isPresented: $showMoreOptions) {
            ActionSheet(
                title: Text("추가 옵션"),
                buttons: [
                    .default(Text("친구 추가")) {
                        // 친구 추가 로직
                    },
                    .default(Text("필터 변경")) {
                        showFilterView = true
                    },
                    .default(Text("신고하기")) {
                        // 신고 로직
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showFilterView) {
            FilterView(currentFilter: $currentFilter)
        }
    }
    
    // 경과 시간 포맷
    var formattedElapsedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// 내 비디오 프리뷰
struct MyVideoPreview: View {
    @Binding var isCameraOn: Bool
    @Binding var isFlipped: Bool
    @Binding var currentFilter: String?
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isCameraOn {
                ZStack {
                    Color.gray
                        .frame(width: 120, height: 160)
                        .cornerRadius(12)
                    
                    Text("👤")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                    
                    // 필터 오버레이
                    if let filter = currentFilter, filter != "없음" {
                        filterOverlay(for: filter)
                    }
                }
            } else {
                Color.black
                    .frame(width: 120, height: 160)
                    .cornerRadius(12)
                    .overlay(
                        VStack {
                            Image(systemName: "video.slash.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                            Text("카메라 꺼짐")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    )
            }
            
            Button(action: {
                isFlipped.toggle()
            }) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
            .padding(8)
        }
        .offset(x: 100)
    }
    
    func filterOverlay(for filter: String) -> some View {
        Group {
            switch filter {
            case "뷰티":
                Color.pink.opacity(0.3)
                    .cornerRadius(12)
            case "반짝이":
                ZStack {
                    ForEach(0..<10) { _ in
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 4, height: 4)
                            .position(
                                x: CGFloat.random(in: 0...120),
                                y: CGFloat.random(in: 0...160)
                            )
                    }
                }
            case "모노톤":
                Color.gray.opacity(0.7)
                    .blendMode(.saturation)
                    .cornerRadius(12)
            case "빈티지":
                Color.yellow.opacity(0.3)
                    .blendMode(.multiply)
                    .cornerRadius(12)
            default:
                EmptyView()
            }
        }
    }
}

// 통화 컨트롤 버튼들
struct CallControlButtons: View {
    @Binding var isMicOn: Bool
    @Binding var isCameraOn: Bool
    @Binding var showDisconnectAlert: Bool
    @Binding var showMoreOptions: Bool
    
    var body: some View {
        HStack(spacing: 20) {
            Button(action: {
                isMicOn.toggle()
            }) {
                Image(systemName: isMicOn ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 24))
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
                    .foregroundColor(.white)
            }
            
            Button(action: {
                showDisconnectAlert = true
            }) {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 24))
                    .padding()
                    .background(Color.red)
                    .clipShape(Circle())
                    .foregroundColor(.white)
            }
            
            Button(action: {
                isCameraOn.toggle()
            }) {
                Image(systemName: isCameraOn ? "video.fill" : "video.slash.fill")
                    .font(.system(size: 24))
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
                    .foregroundColor(.white)
            }
            
            Button(action: {
                showMoreOptions = true
            }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 24))
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
                    .foregroundColor(.white)
            }
        }
    }
}

// 연결 중 화면
struct ConnectingView: View {
    @State private var dots = ""
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    var onConnected: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("연결 중\(dots)")
                    .font(.title)
                    .foregroundColor(.white)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("적합한 상대를 찾고 있습니다")
                    .foregroundColor(.gray)
                
                Button(action: {
                    onConnected()
                }) {
                    Text("취소")
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                }
                .padding(.top, 20)
            }
            .padding()
        }
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 4
            dots = String(repeating: ".", count: dotCount)
            
            // 테스트를 위해 3초 후 자동 연결
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                onConnected()
            }
        }
    }
}

// 카메라 미리보기 뷰
struct CameraPreviewView: View {
    var isCameraOn: Bool
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if isCameraOn {
                Color.gray.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    Spacer()
                    
                    Text("👤")
                        .font(.system(size: 100))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("카메라 미리보기")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                }
            } else {
                VStack {
                    Spacer()
                    
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("카메라가 꺼져 있습니다")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top)
                    
                    Text("화상 채팅을 시작하려면 카메라를 켜주세요")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                    
                    Spacer()
                }
            }
        }
    }
}