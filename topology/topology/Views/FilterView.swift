import SwiftUI

// 필터 뷰
struct FilterView: View {
    @Binding var currentFilter: String?
    @Environment(\.presentationMode) var presentationMode
    
    // 필터 옵션
    let filterOptions = [
        "없음", "뷰티", "반짝이", "모노톤", "빈티지",
        "모자이크", "선글라스", "고양이", "강아지", "토끼"
    ]
    
    // 프리미엄 필터 (보석 필요)
    let premiumFilters = ["모자이크", "선글라스", "고양이", "강아지", "토끼"]
    
    @State private var selectedFilter: String? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                // 필터 프리뷰
                FilterPreview(selectedFilter: $selectedFilter)
                
                // 필터 그리드
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(filterOptions, id: \.self) { filter in
                            FilterOptionButton(
                                filter: filter,
                                isSelected: selectedFilter == filter,
                                isPremium: premiumFilters.contains(filter),
                                onTap: {
                                    selectedFilter = filter
                                }
                            )
                        }
                    }
                    .padding()
                }
                
                // 적용 버튼
                Button(action: {
                    currentFilter = selectedFilter
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("적용하기")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("필터 선택")
            .navigationBarItems(trailing: Button("취소") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                selectedFilter = currentFilter
            }
        }
    }
}

// 필터 프리뷰
struct FilterPreview: View {
    @Binding var selectedFilter: String?
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .frame(height: 250)
                .cornerRadius(16)
            
            if let filter = selectedFilter, filter != "없음" {
                Text("👤")
                    .font(.system(size: 100))
                    .overlay(
                        filterOverlay(for: filter)
                    )
            } else {
                Text("👤")
                    .font(.system(size: 100))
            }
            
            VStack {
                Spacer()
                Text(selectedFilter ?? "기본")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(20)
                    .padding(.bottom, 20)
            }
        }
        .padding()
    }
    
    func filterOverlay(for filter: String) -> some View {
        Group {
            switch filter {
            case "뷰티":
                Color.pink.opacity(0.3)
                    .cornerRadius(16)
            case "반짝이":
                ZStack {
                    ForEach(0..<20) { i in
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: CGFloat.random(in: 4...8))
                            .position(
                                x: CGFloat.random(in: -50...50),
                                y: CGFloat.random(in: -50...50)
                            )
                            .opacity(Double.random(in: 0.5...1.0))
                    }
                }
            case "모노톤":
                Color.gray.opacity(0.7)
                    .blendMode(.saturation)
                    .cornerRadius(16)
            case "빈티지":
                ZStack {
                    Color.sepia.opacity(0.3)
                        .blendMode(.multiply)
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black.opacity(0.3)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .cornerRadius(16)
            case "모자이크":
                GeometryReader { geometry in
                    ForEach(0..<10) { row in
                        ForEach(0..<10) { col in
                            Rectangle()
                                .fill(Color.random.opacity(0.3))
                                .frame(width: 10, height: 10)
                                .position(
                                    x: CGFloat(col * 10 - 45),
                                    y: CGFloat(row * 10 - 45)
                                )
                        }
                    }
                }
            case "선글라스":
                Image(systemName: "eyeglasses")
                    .font(.system(size: 50))
                    .foregroundColor(.black)
                    .offset(y: -20)
            case "고양이":
                VStack {
                    HStack(spacing: 40) {
                        Text("🦻")
                            .font(.system(size: 30))
                            .rotationEffect(.degrees(-30))
                        Text("🦻")
                            .font(.system(size: 30))
                            .rotationEffect(.degrees(30))
                            .scaleEffect(x: -1, y: 1)
                    }
                    .offset(y: -50)
                    
                    Text("🐱")
                        .font(.system(size: 20))
                        .offset(y: 0)
                }
            case "강아지":
                VStack {
                    HStack(spacing: 50) {
                        Text("🦴")
                            .font(.system(size: 25))
                            .rotationEffect(.degrees(-20))
                        Text("🦴")
                            .font(.system(size: 25))
                            .rotationEffect(.degrees(20))
                            .scaleEffect(x: -1, y: 1)
                    }
                    .offset(y: -50)
                    
                    Text("🐶")
                        .font(.system(size: 20))
                        .offset(y: 0)
                }
            case "토끼":
                VStack {
                    HStack(spacing: 30) {
                        Text("🥕")
                            .font(.system(size: 30))
                            .rotationEffect(.degrees(-10))
                        Text("🥕")
                            .font(.system(size: 30))
                            .rotationEffect(.degrees(10))
                            .scaleEffect(x: -1, y: 1)
                    }
                    .offset(y: -50)
                    
                    Text("🐰")
                        .font(.system(size: 20))
                        .offset(y: 0)
                }
            default:
                EmptyView()
            }
        }
    }
}

// 필터 옵션 버튼
struct FilterOptionButton: View {
    let filter: String
    let isSelected: Bool
    let isPremium: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color.green : Color.clear, lineWidth: 3)
                        )
                    
                    if filter == "없음" {
                        Image(systemName: "xmark")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    } else {
                        Text("Aa")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                            .overlay(
                                filterIcon(for: filter)
                            )
                    }
                    
                    if isPremium {
                        VStack {
                            HStack {
                                Spacer()
                                
                                Image(systemName: "diamond.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 14))
                                    .padding(4)
                                    .background(Color.black.opacity(0.8))
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                        }
                    }
                }
                
                Text(filter)
                    .font(.caption)
                    .foregroundColor(isSelected ? .green : .gray)
            }
        }
    }
    
    func filterIcon(for filter: String) -> some View {
        Group {
            switch filter {
            case "뷰티":
                Color.pink.opacity(0.5)
                    .clipShape(Circle())
                    .frame(width: 60, height: 60)
            case "반짝이":
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                    .font(.system(size: 20))
            case "모노톤":
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 60, height: 60)
            case "빈티지":
                Circle()
                    .fill(Color.brown.opacity(0.5))
                    .frame(width: 60, height: 60)
            case "모자이크":
                Image(systemName: "square.grid.3x3")
                    .foregroundColor(.blue)
                    .font(.system(size: 20))
            case "선글라스":
                Text("🕶️")
                    .font(.system(size: 30))
            case "고양이":
                Text("🐱")
                    .font(.system(size: 30))
            case "강아지":
                Text("🐶")
                    .font(.system(size: 30))
            case "토끼":
                Text("🐰")
                    .font(.system(size: 30))
            default:
                EmptyView()
            }
        }
    }
}

// 색상 확장
extension Color {
    static var sepia: Color {
        Color(red: 0.44, green: 0.35, blue: 0.22)
    }
    
    static var random: Color {
        Color(
            red: Double.random(in: 0...1),
            green: Double.random(in: 0...1),
            blue: Double.random(in: 0...1)
        )
    }
}