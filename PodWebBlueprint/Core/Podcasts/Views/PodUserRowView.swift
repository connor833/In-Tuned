//
//  PodUserRowView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 3/27/23.
//
//
//  PodRowView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/2/23.
//

import SwiftUI
import Kingfisher
import Firebase

struct PodRowUserView: View {
    @State private var showingComments = false
    @State private var showingSendView = false
    @ObservedObject var viewModel: PodViewModel
    
    let pod: Pod
    
    init(pod: Pod) {
        self.viewModel = PodViewModel(pod: pod)
        self.pod = pod
    }
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                KFImage(URL(string: pod.thumbnailUrl))
                    .resizable()
                    .aspectRatio(contentMode: .fill) // Keep fill for square display
                    .frame(width: 42, height: 42)
                    .clipped() // Add clipped to ensure square display
                    .cornerRadius(8)
                    .foregroundColor(Color("accentColor"))
                
                
                VStack(alignment: .leading) {
                    Text(pod.title)
                        .foregroundColor(Color("accentColor"))
                        .font(.system(size: 24))
                    
                    
                    HStack() {
                        Text("Pod Web")
                            .foregroundColor(.gray)
                            .font(.system(size: 12))
                            
                        Text("@Pod Web")
                                .foregroundColor(Color(.systemBlue))
                                .font(.system(size: 12))
                            
                            
                    }
                    
                }
                .padding()
                Spacer()
                Spacer()
                Spacer()
                
            }
            .font(.system(size: 24))
            
            VStack {
                HStack (spacing: 48){
                    
                    Button {
                        viewModel.pod.didLike ?? false ?
                        viewModel.unlikePod() :
                        viewModel.likePod()
                    } label: {
                        Image(systemName: viewModel.pod.didLike ?? false ?  "heart.fill" : "heart")
                            .font(.subheadline)
                            .foregroundColor(viewModel.pod.didLike ?? false ? .red : .gray)
                    }
                    
 
                    
                    Button {
                        showingComments.toggle()
                    } label: {
                        Image(systemName: "text.bubble")
                    }
                    .sheet (isPresented: $showingComments){
                        if #available(iOS 16.0, *) {
                            CommentsView(pod: pod, comment: PreviewClass().previewComment)
                                .presentationDetents([.fraction(0.80)])
                                .presentationDragIndicator(.hidden)
                        } else {
                            CommentsView(pod: pod, comment: PreviewClass().previewComment)
                        }
                    }
                    
                    Button {
                        viewModel.pod.didSave ?? false ?
                        viewModel.unsavePod() :
                        viewModel.savePod()
                    } label: {
                       viewModel.pod.didSave ?? false ?
                            Image(systemName: "archivebox.fill") : Image(systemName: "archivebox")
                    }
                    
                    /* send view
                    Button {
                        showingSendView.toggle()
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .sheet (isPresented: $showingSendView){
                        if #available(iOS 16.0, *) {
                            SendPodView()
                                .presentationDetents([.fraction(0.80)])
                                .presentationDragIndicator(.hidden)
                        } else {
                            SendPodView()
                        }
                    }
                     */
                    
                    Menu {
                        Button {
                            viewModel.deletePod()
                        } label: {
                            Text("Delete Pod")
                            Image(systemName: "flag")
                        }

                    } label: {
                        Image(systemName: "ellipsis")
                    }


                }
                .foregroundColor(Color("accentColor"))
                
                Divider()
                    .foregroundColor(.gray)
                    .padding()
            }
            
        }
    }
}

struct PodRowUserView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack{
                ForEach(0..<25) { _ in
                    PodRowUserView(pod: PreviewClass().previewPod)
                }
            }
        }
    }
}
