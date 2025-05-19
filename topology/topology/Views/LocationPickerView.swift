import SwiftUI

// 위치 선택 뷰
struct LocationPickerView: View {
    @Binding var selectedLocation: String
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    @State private var selectedTab = 0
    
    // 한국 주요 도시
    let koreanCities = [
        "서울", "부산", "인천", "대구", "대전", 
        "광주", "울산", "세종", "수원", "성남",
        "용인", "고양", "창원", "청주", "천안",
        "전주", "안산", "평택", "제주", "김해"
    ]
    
    // 글로벌 옵션
    let globalOptions = [
        "미국", "일본", "중국", "영국", "프랑스", 
        "독일", "캐나다", "호주", "인도", "브라질",
        "러시아", "이탈리아", "스페인", "네덜란드", "스위스",
        "스웨덴", "노르웨이", "덴마크", "싱가포르", "태국"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 탭 선택
                Picker("", selection: $selectedTab) {
                    Text("국내").tag(0)
                    Text("해외").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // 검색 바
                SearchBar(searchText: $searchText)
                
                // 위치 목록
                List {
                    if selectedTab == 0 {
                        ForEach(filteredKoreanCities, id: \.self) { city in
                            LocationRow(
                                location: city,
                                isSelected: selectedLocation == city,
                                onTap: {
                                    selectedLocation = city
                                    presentationMode.wrappedValue.dismiss()
                                }
                            )
                        }
                    } else {
                        ForEach(filteredGlobalOptions, id: \.self) { country in
                            LocationRow(
                                location: country,
                                isSelected: selectedLocation == country,
                                onTap: {
                                    selectedLocation = country
                                    presentationMode.wrappedValue.dismiss()
                                }
                            )
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("위치 선택")
            .navigationBarItems(trailing: Button("취소") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    var filteredKoreanCities: [String] {
        if searchText.isEmpty {
            return koreanCities
        } else {
            return koreanCities.filter { $0.contains(searchText) }
        }
    }
    
    var filteredGlobalOptions: [String] {
        if searchText.isEmpty {
            return globalOptions
        } else {
            return globalOptions.filter { $0.contains(searchText) }
        }
    }
}

// 위치 행
struct LocationRow: View {
    let location: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.green)
                    .frame(width: 30)
                
                Text(location)
                    .foregroundColor(.white)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

// 검색 바
struct SearchBar: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("검색", text: $searchText)
                .foregroundColor(.white)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// 성별 선택 뷰
struct GenderPickerView: View {
    @Binding var selectedGender: String
    @Environment(\.presentationMode) var presentationMode
    
    let genderOptions = ["모두", "여성", "남성"]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(genderOptions, id: \.self) { gender in
                    GenderRow(
                        gender: gender,
                        isSelected: selectedGender == gender,
                        onTap: {
                            selectedGender = gender
                            presentationMode.wrappedValue.dismiss()
                        }
                    )
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("성별 선택")
            .navigationBarItems(trailing: Button("취소") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// 성별 행
struct GenderRow: View {
    let gender: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var genderIcon: String {
        switch gender {
        case "모두": return "person.2.fill"
        case "여성": return "person.fill"
        case "남성": return "person.fill"
        default: return "person.fill"
        }
    }
    
    var genderColor: Color {
        switch gender {
        case "모두": return .green
        case "여성": return .pink
        case "남성": return .blue
        default: return .gray
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: genderIcon)
                    .foregroundColor(genderColor)
                    .frame(width: 30)
                
                Text(gender)
                    .foregroundColor(.white)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 8)
        }
    }
}