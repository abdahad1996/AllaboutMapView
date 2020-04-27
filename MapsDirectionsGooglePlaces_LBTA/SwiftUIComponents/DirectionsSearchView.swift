//
//  DirectionsSearchView.swift
//  MapsDirectionsGooglePlaces_LBTA
//
//  Created by Brian Voong on 12/13/19.
//  Copyright © 2019 Brian Voong. All rights reserved.
//

import SwiftUI
import MapKit

struct DirectionsMapView: UIViewRepresentable {
    
    @EnvironmentObject var env: DirectionsEnvironment
    
    typealias UIViewType = MKMapView
    
    let mapView = MKMapView()
    
    func makeCoordinator() -> DirectionsMapView.Coordinator {
        return Coordinator(mapView: mapView)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        
        init(mapView: MKMapView) {
            super.init()
            mapView.delegate = self
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = .red
            renderer.lineWidth = 5
            return renderer
        }
        
    }
    
    func makeUIView(context: UIViewRepresentableContext<DirectionsMapView>) -> MKMapView {
        mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: UIViewRepresentableContext<DirectionsMapView>) {
        
        uiView.removeOverlays(uiView.overlays)
        uiView.removeAnnotations(uiView.annotations)
        
        [env.sourceMapItem, env.destinationMapItem].compactMap{$0}.forEach { (mapItem) in
            let annotation = MKPointAnnotation()
            annotation.title = mapItem.name
            annotation.coordinate = mapItem.placemark.coordinate
            uiView.addAnnotation(annotation)
        }
        uiView.showAnnotations(uiView.annotations, animated: false)
        
        if let route = env.route {
            uiView.addOverlay(route.polyline)
        }
        
    }
}

struct SelectLocationView: View {
    
    @EnvironmentObject var env: DirectionsEnvironment
    
    // here is the magic
//    @Binding var isShowing: Bool
    @State var mapItems = [MKMapItem]()
    @State var searchQuery = ""
    
    var body: some View {
        VStack {
            
            HStack (spacing: 16) {
                Button(action: {
                    self.env.isSelectingSource = false
                    self.env.isSelectingDestination = false
                    
                }, label: {
                    Image(uiImage: #imageLiteral(resourceName: "back_arrow"))
                }).foregroundColor(.black)
                
                TextField("Enter search term", text: $searchQuery)
                    .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidChangeNotification).debounce(for: .milliseconds(500), scheduler: RunLoop.main)) { _ in
                    
                        // search
                        let request = MKLocalSearch.Request()
                        request.naturalLanguageQuery = self.searchQuery
                        let search = MKLocalSearch(request: request)
                        search.start { (resp, err) in
                            // check your error
                            self.mapItems = resp?.mapItems ?? []
                        }
                }
            }.padding()
            
            if mapItems.count > 0 {
                ScrollView {
                    ForEach(mapItems, id: \.self) { item in
                        Button(action: {
                            if self.env.isSelectingSource {
                                self.env.isSelectingSource = false
                                self.env.sourceMapItem = item
                            } else {
                                self.env.isSelectingDestination = false
                                self.env.destinationMapItem = item
                            }
                        }) {
                            HStack {
                                VStack (alignment: .leading) {
                                    Text("\(item.name ?? "")")
                                        .font(.headline)
                                    Text("\(item.address())")
                                }
                                Spacer()
                            }
                            .padding()
                        }.foregroundColor(.black)
                        
                    }
                }
            }
            Spacer()
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarTitle("")
        .navigationBarHidden(true)
    }
}

struct DirectionsSearchView: View {
    
    @EnvironmentObject var env: DirectionsEnvironment
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        
                        MapItemView(selectingBool: $env.isSelectingSource, title: env.sourceMapItem != nil ? (env.sourceMapItem?.name ?? "") : "Source", image: #imageLiteral(resourceName: "start_location_circles"))
                        
                        MapItemView(selectingBool: $env.isSelectingDestination, title: env.destinationMapItem != nil ? (env.destinationMapItem?.name ?? "") : "Destination", image: #imageLiteral(resourceName: "annotation_icon"))
                    }
                    .padding()
                    .background(Color.blue)
                    
                    DirectionsMapView().edgesIgnoringSafeArea(.bottom)
                }
                StatusBarCover()
                
                if env.isCalculatingDirections {
                    VStack {
                        Spacer()
                        VStack {
                            LoadingHUD()
                            Text("Loading...")
                                .font(.headline)
                                .foregroundColor(.white)
                            }.padding()
                        .background(Color.black)
                            .cornerRadius(5)
                        
                        Spacer()
                    }
                }
                
            }
        .navigationBarTitle("DIRECTIONS")
            .navigationBarHidden(true)
        }
    }
}

struct LoadingHUD: UIViewRepresentable {
    typealias UIViewType = UIActivityIndicatorView
    
    func makeUIView(context: UIViewRepresentableContext<LoadingHUD>) -> UIActivityIndicatorView {
        let aiv = UIActivityIndicatorView(style: .large)
        aiv.color = .white
        aiv.startAnimating()
        return aiv
    }
    
    func updateUIView(_ uiView: UIActivityIndicatorView, context: UIViewRepresentableContext<LoadingHUD>) {
        
    }
}

struct MapItemView: View {
    @EnvironmentObject var env: DirectionsEnvironment
    
    @Binding var selectingBool: Bool
    var title: String
    var image: UIImage
    
    var body: some View {
        HStack(spacing: 16) {
            Image(uiImage: image.withRenderingMode(.alwaysTemplate)).frame(width: 24).foregroundColor(.white)
            
            NavigationLink(destination: SelectLocationView(), isActive: $selectingBool) {
                
                HStack {
                    Text(title)
                    Spacer()
                }
                .padding() .background(Color.white).cornerRadius(3)
            }
        }
    }
}

struct StatusBarCover: View {
    var body: some View {
        Spacer().frame(width: UIApplication.shared.windows.filter{$0.isKeyWindow}.first?.frame.width, height: UIApplication.shared.windows.filter{$0.isKeyWindow}.first?.safeAreaInsets.top)
        .background(Color.blue)
        .edgesIgnoringSafeArea(.top)
    }
}

import Combine

// treat your env as the brain of your application
class DirectionsEnvironment: ObservableObject {
    @Published var isCalculatingDirections = false
    
    @Published var isSelectingSource = false
    @Published var isSelectingDestination = false
    
    @Published var sourceMapItem: MKMapItem?
    @Published var destinationMapItem: MKMapItem?
    
    @Published var route: MKRoute?
    
    var cancellable: AnyCancellable?
    
    init() {
        // listen for changes on sourceMapItem, destinationMapitem
        cancellable = Publishers.CombineLatest($sourceMapItem, $destinationMapItem).sink { [weak self] (items) in
//            print(items.0 ?? "", items.1 ?? "")
            
            // searching for directions
            let request = MKDirections.Request()
            request.source = items.0
            request.destination = items.1
            let directions = MKDirections(request: request)
            
            self?.isCalculatingDirections = true
            self?.route = nil
            
            directions.calculate { [weak self] (resp, err) in
                self?.isCalculatingDirections = false
                if let err = err {
                    print("Failed to calculate directions:", err)
                    return
                }
                
//                print(resp?.routes.first ?? "")
                self?.route = resp?.routes.first
            }
        }
    }
}

struct DirectionsSearchView_Previews: PreviewProvider {
    static var env = DirectionsEnvironment()
    
    static var previews: some View {
        DirectionsSearchView().environmentObject(env)
    }
}



//struct SourceMapItemView: View {
//    @EnvironmentObject var env: DirectionsEnvironment
//
//    var body: some View {
//        HStack(spacing: 16) {
//            Image(uiImage: #imageLiteral(resourceName: "start_location_circles")).frame(width: 24)
//
//            NavigationLink(destination: SelectLocationView(), isActive: $env.isSelectingSource) {
//
//                HStack {
//                    Text(env.sourceMapItem != nil ? (env.sourceMapItem?.name ?? "") : "Source")
//                    Spacer()
//                }
//                .padding() .background(Color.white).cornerRadius(3)
//            }
//        }
//    }
//}
//
//struct DestinationMapItemView: View {
//    @EnvironmentObject var env: DirectionsEnvironment
//
//    var body: some View {
//        HStack(spacing: 16) {
//            Image(uiImage: #imageLiteral(resourceName: "annotation_icon").withRenderingMode(.alwaysTemplate)).foregroundColor(.white)
//                .frame(width: 24)
//
//            NavigationLink(destination: SelectLocationView(), isActive: $env.isSelectingDestination) {
//
//                HStack {
//                    Text(env.destinationMapItem != nil ? (env.destinationMapItem?.name ?? "") : "Destination")
//                    Spacer()
//                }
//                .padding() .background(Color.white).cornerRadius(3)
//            }
//        }
//    }
//}
