//
//  HomeView.swift
//  Tracky
//
//  Created by McKiba Williams on 7/13/24.
//

import SwiftUI

struct HomeView: View {
    
    @State var currentTab: String = "home"
    @Namespace var animation
    @StateObject var activityVM = ActivityController()

    var body: some View {
        HStack(spacing: 0){
            //Side Bar Menu
            VStack(spacing: 20){
                //Menu Buttons
                ForEach(["house","person", "chart.bar", "graph", "gear"],id: \.self){
                    image in MenuButton(image: image)
                }
            }
            .padding(.top, 65)
            .frame(width: 85)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .background(
                ZStack {
                    Color(red: 0.13, green: 0.13, blue: 0.18).padding(.trailing, 30)
                        .background(Color(red: 0.13, green: 0.13, blue: 0.18))
                        .cornerRadius(15).shadow(color: Color.black.opacity(0.03), radius: 5, x: 5, y: 0)
                }
                .ignoresSafeArea()
            )
            
            //Home View
            VStack(spacing: 20) {
                
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundColor(.white)
                    TextField("Search", text: .constant(""))
                        .foregroundColor(.clear)
                        .frame(width: 475, height: 14,alignment: .leading)
                        .background(Color(red: 0.13, green: 0.13, blue: 0.18))


                }
                .padding(.vertical, 8)
                .padding(.horizontal)
                .background(Color(red: 0.13, green: 0.13, blue: 0.18))
                .clipShape(Capsule())
                .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 10) {
                                  if activityVM.showCameraView {
                                      CameraView(activityVM: activityVM)
                                  } else {
                                      CreateActivity(activityVM: activityVM)
                                          .frame(maxWidth: .infinity, alignment: .leading)
                                          .ignoresSafeArea()
                                      
                                      Rectangle()
                                          .foregroundColor(.clear)
                                          .frame(width: 307, height: 808)
                                          .background(Color(red: 0.13, green: 0.13, blue: 0.18))
                                          .cornerRadius(32)
                              }
                }.padding(.horizontal, 1)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
            
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame( /*height: getRect().height - 130, */width: getRect().width, alignment: .leading)
        .background(Color(red: 0.09, green: 0.09, blue: 0.13).ignoresSafeArea())
 
        //Applying button style to whole View
        .buttonStyle(BorderedButtonStyle())
        .textFieldStyle(PlainTextFieldStyle())
    }
    
    @ViewBuilder
    func MenuButton(image: String) -> some View {
        Image(image)
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .foregroundColor(currentTab == image ? .blue : .white)
            .frame(width: 22, height: 22)
            .frame(width: 80, height: 50)
            .overlay(
                HStack{
                    if currentTab == image {
                        Capsule()
                            .fill(Color.blue)
                            .matchedGeometryEffect(id:"TAB", in: animation)
                            .frame(width: 2, height: 40)
                            .offset(x: 2)
                    }
                }
                ,alignment: .trailing
                
            ).contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring()){
                    currentTab = image
                }
            }
    }
}

#Preview {
    HomeView()
}


extension View{
    func getRect()->CGRect{
        return NSScreen.main!.visibleFrame
    }
}
