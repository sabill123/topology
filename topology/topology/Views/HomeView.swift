import SwiftUI
import AVFoundation

struct HomeView: View {
    @State private var isFilterViewPresented = false
    @State private var currentFilter: String? = nil
    @State private var showLocationOption = false
    @State private var showGenderOption = false
    @State private var isCameraOn = true
    @State private var isMicOn = true
    @State private var isFlipped = false
    @State private var showRandomCallAlert = false
    @State private var showLocationPicker = false
    @State private var showGenderPicker = false
    @State private var selectedLocation = "서울"
    @State private var selectedGender = "모두"
    @State private var isConnecting = false
    @State private var isChatting = false
    @State private var currentChatPartner: Friend? = nil
    
    // 카메라 관련 상태
    @State private var cameraAccess = true
    
    var body: some View {
        NavigationView {
            ZStack {
                // 카메라 뷰 (실제 앱에서는 AVCaptureSession을 사용해야 함)
                if isChatting, let partner = currentChatPartner {
                    VideoCallSessionView(
                        partner: partner,
                        isCameraOn: $isCameraOn,
                        isMicOn: $isMicOn,
                        isFlipped: $isFlipped,
                        onDisconnect: {
                            isChatting = false
                            currentChatPartner = nil
                        }
                    )
                } else {
                    CameraPreviewView(isCameraOn: isCameraOn)
                        .edgesIgnoringSafeArea(.all)
                }
                
                if isConnecting {
                    ConnectingView {
                        isConnecting = false
                        // 랜덤 상대를 찾으면 채팅 시작
                        let randomFriend = generateRandomFriend()
                        currentChatPartner = randomFriend
                        isChatting = true
                    }
                }
                
                if !isChatting {
                    // 상단 앱 바
                    VStack {
                        HStack {
                            Button(action: {
                                // 알림
                            }) {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            // 포인트 표시
                            HStack(spacing: 4) {
                                Text("1,595")
                                    .font(.system(size: 14, weight: .bold))
                                Image(systemName: "diamond.fill")
                                    .foregroundColor(.yellow)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(20)
                            
                            // Plus 버튼
                            NavigationLink(destination: GemStoreView(viewModel: FriendsViewModel())) {
                                HStack {
                                    Text("Plus")
                                        .font(.system(size: 14, weight: .bold))
                                        .italic()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(20)
                            }
                            
                            Spacer()
                            
                            // 프로필 이미지
                            NavigationLink(destination: ProfileView()) {
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Text("👤")
                                            .font(.system(size: 18))
                                    )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        Spacer()
                        
                        // 왼쪽 사이드 버튼들
                        VStack(spacing: 20) {
                            Button(action: {
                                isFilterViewPresented = true
                            }) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            
                            Button(action: {
                                isFlipped.toggle()
                            }) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            
                            Button(action: {
                                // 새로고침
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                        }
                        .padding()
                        .offset(x: -UIScreen.main.bounds.width/2 + 50)
                        
                        Spacer()
                        
                        // 하단 옵션 버튼들
                        VStack(spacing: 12) {
                            // 화상 채팅 시작 버튼
                            Button(action: {
                                if cameraAccess {
                                    showRandomCallAlert = true
                                }
                            }) {
                                HStack {
                                    Text("화상채팅 시작하기")
                                        .font(.system(size: 16, weight: .bold))
                                    Image(systemName: "hand.point.right.fill")
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .cornerRadius(30)
                            }
                            
                            HStack(spacing: 0) {
                                // 위치 선택 버튼
                                Button(action: {
                                    showLocationPicker = true
                                }) {
                                    HStack {
                                        Image(systemName: "location.fill")
                                            .foregroundColor(.green)
                                        Text(selectedLocation)
                                            .foregroundColor(.white)
                                        Image(systemName: "chevron.up")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                            .rotationEffect(showLocationPicker ? .degrees(180) : .degrees(0))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(20)
                                }
                                
                                Spacer()
                                
                                // 성별 선택 버튼
                                Button(action: {
                                    showGenderPicker = true
                                }) {
                                    HStack {
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.pink)
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.blue)
                                        Text(selectedGender)
                                            .foregroundColor(.white)
                                        Image(systemName: "chevron.up")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                            .rotationEffect(showGenderPicker ? .degrees(180) : .degrees(0))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(20)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 16)
                    }
                }
            }
            .sheet(isPresented: $isFilterViewPresented) {
                FilterView(currentFilter: $currentFilter)
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView(selectedLocation: $selectedLocation)
            }
            .sheet(isPresented: $showGenderPicker) {
                GenderPickerView(selectedGender: $selectedGender)
            }
            .alert(isPresented: $showRandomCallAlert) {
                Alert(
                    title: Text("랜덤 화상통화"),
                    message: Text("전 세계 사용자와 랜덤으로 연결됩니다. 계속하시겠습니까?"),
                    primaryButton: .default(Text("시작하기")) {
                        startRandomCall()
                    },
                    secondaryButton: .cancel(Text("취소"))
                )
            }
            .navigationBarHidden(true)
        }
    }
    
    // 랜덤 통화 시작 함수
    func startRandomCall() {
        isConnecting = true
    }
    
    // 테스트용 랜덤 친구 생성 함수
    func generateRandomFriend() -> Friend {
        let names = ["소피아", "재클린", "알렉스", "하루카", "마리아", "아미르"]
        let countries = ["미국", "영국", "일본", "한국", "러시아", "프랑스"]
        let randomName = names.randomElement() ?? "사용자"
        let randomCountry = countries.randomElement() ?? "미국"
        return Friend(
            name: randomName,
            profileImage: "person.fill",
            age: Int.random(in: 20...35),
            country: randomCountry,
            isOnline: true,
            lastSeen: "방금 전"
        )
    }
}