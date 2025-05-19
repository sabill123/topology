import SwiftUI

struct RecentCallsView: View {
    @StateObject private var viewModel = FriendsViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 탭 선택 (전체/부재중)
                HStack {
                    Button(action: {
                        selectedTab = 0
                    }) {
                        Text("전체")
                            .font(.headline)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .background(selectedTab == 0 ? Color.green : Color.clear)
                            .foregroundColor(selectedTab == 0 ? .white : .gray)
                            .cornerRadius(20)
                    }
                    
                    Button(action: {
                        selectedTab = 1
                    }) {
                        HStack {
                            Text("부재중")
                            if missedCallsCount > 0 {
                                Text("\(missedCallsCount)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                        }
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(selectedTab == 1 ? Color.green : Color.clear)
                        .foregroundColor(selectedTab == 1 ? .white : .gray)
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    // 통화 기록 삭제
                    Button(action: {
                        // 통화 기록 전체 삭제
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // 통화 기록 목록
                if filteredCallRecords.isEmpty {
                    EmptyCallsView()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(filteredCallRecords) { record in
                                CallRecordRow(record: record)
                                    .contextMenu {
                                        Button(action: {
                                            // 다시 전화하기
                                        }) {
                                            Label("다시 전화하기", systemImage: "phone.fill")
                                        }
                                        
                                        Button(action: {
                                            // 메시지 보내기
                                        }) {
                                            Label("메시지 보내기", systemImage: "message.fill")
                                        }
                                        
                                        Button(action: {
                                            // 기록 삭제
                                        }) {
                                            Label("삭제", systemImage: "trash")
                                                .foregroundColor(.red)
                                        }
                                    }
                                
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("통화 기록")
        }
    }
    
    var filteredCallRecords: [CallRecord] {
        if selectedTab == 0 {
            return viewModel.callRecords
        } else {
            // 부재중 통화만 필터링 (여기서는 임의로 incoming이 false인 것을 부재중으로 간주)
            return viewModel.callRecords.filter { !$0.isIncoming }
        }
    }
    
    var missedCallsCount: Int {
        viewModel.callRecords.filter { !$0.isIncoming }.count
    }
}

// 통화 기록 행
struct CallRecordRow: View {
    let record: CallRecord
    
    var body: some View {
        HStack(spacing: 12) {
            // 프로필 이미지
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                Text("👤")
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(record.friend.name)
                        .font(.headline)
                    
                    if record.friend.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 12))
                    }
                }
                
                HStack(spacing: 4) {
                    // 통화 방향 아이콘
                    Image(systemName: record.isIncoming ? "phone.down.fill" : "phone.fill")
                        .foregroundColor(record.isIncoming ? .green : .blue)
                        .font(.system(size: 12))
                    
                    // 통화 유형
                    Image(systemName: record.isVideoCall ? "video.fill" : "phone.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 12))
                    
                    // 통화 시간
                    Text(formatCallTime(record.startTime))
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    // 통화 시간 (duration)
                    Text("(\(formatDuration(record.duration)))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // 정보 버튼
            Button(action: {
                // 상세 정보 표시
            }) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
    }
    
    func formatCallTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "a h:mm"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'어제' a h:mm"
        } else {
            formatter.dateFormat = "M월 d일"
        }
        
        return formatter.string(from: date)
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes)분 \(seconds)초"
        } else {
            return "\(seconds)초"
        }
    }
}

// 빈 통화 기록 뷰
struct EmptyCallsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "phone.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("통화 기록이 없습니다")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("친구들과 통화를 시작해보세요")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
}

// 통화 상세 정보 뷰
struct CallDetailView: View {
    let record: CallRecord
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 친구 정보
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 80)
                        
                        Text("👤")
                            .font(.system(size: 40))
                    }
                    
                    VStack(alignment: .leading) {
                        Text(record.friend.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("\(record.friend.age)세 • \(record.friend.country)")
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                .padding()
                
                // 통화 정보
                VStack(alignment: .leading, spacing: 16) {
                    InfoRow(icon: record.isVideoCall ? "video.fill" : "phone.fill",
                           title: "통화 유형",
                           value: record.isVideoCall ? "영상통화" : "음성통화")
                    
                    InfoRow(icon: record.isIncoming ? "phone.down.fill" : "phone.fill",
                           title: "통화 방향",
                           value: record.isIncoming ? "수신" : "발신")
                    
                    InfoRow(icon: "clock.fill",
                           title: "통화 시간",
                           value: formatFullDate(record.startTime))
                    
                    InfoRow(icon: "timer",
                           title: "통화 시간",
                           value: formatFullDuration(record.duration))
                }
                .padding()
                .background(Color.black.opacity(0.2))
                .cornerRadius(12)
                
                Spacer()
                
                // 액션 버튼들
                HStack(spacing: 20) {
                    Button(action: {
                        // 다시 전화하기
                    }) {
                        VStack {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.green)
                                .clipShape(Circle())
                            
                            Text("전화하기")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    NavigationLink(destination: ChatView(friend: record.friend)) {
                        VStack {
                            Image(systemName: "message.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.blue)
                                .clipShape(Circle())
                            
                            Text("메시지")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    NavigationLink(destination: FriendDetailView(friend: record.friend, viewModel: FriendsViewModel())) {
                        VStack {
                            Image(systemName: "person.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.orange)
                                .clipShape(Circle())
                            
                            Text("프로필")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("통화 상세")
            .navigationBarItems(trailing: Button("닫기") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일 a h:mm"
        return formatter.string(from: date)
    }
    
    func formatFullDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return "\(hours)시간 \(minutes)분 \(seconds)초"
        } else if minutes > 0 {
            return "\(minutes)분 \(seconds)초"
        } else {
            return "\(seconds)초"
        }
    }
}