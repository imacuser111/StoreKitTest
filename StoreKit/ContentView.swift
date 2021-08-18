//
//  ContentView.swift
//  StoreKit
//
//  Created by Cheng-Hong on 2021/8/17.
//

import SwiftUI

struct ContentView: View {
    
    @ObservedObject var iapManager = IAPManager.shared
    
    var body: some View {
        VStack {
//            ForEach(IAPManager.shared.getProductIDs() ?? [], id: \.self) { item in
//                Text(item)
//                    .onTapGesture {
//                        let products = IAPManager.shared.products.filter{ $0.productIdentifier == item }
//                        if let product = products.first {
//                            IAPManager.shared.buy(product: product)
//                        }
//                    }
//                    .background(Color(UIColor.green))
//                    .padding()
//            }
            
            ForEach(IAPManager.shared.products, id: \.self) { item in
                Text(item.localizedTitle)
                    .onTapGesture {
                        IAPManager.shared.buy(product: item)
                    }
                    .background(Color(UIColor.green))
                    .padding()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
