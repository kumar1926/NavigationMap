//
//  RouteTimeAnnotation.swift
//  NavigationMap
//
//  Created by BizMagnets on 04/11/25.
//

import SwiftUI

struct RouteTimeAnnotation:View {
    var time:String
    var isPrimary:Bool
    var body: some View {
        Text(time)
            .font(.caption)
            .bold()
            .padding(isPrimary ? 7:6)
            .foregroundStyle(isPrimary ? Color.white:Color.yellow.opacity(0.8))
            .background(isPrimary ? Color.blue:Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .shadow(radius: isPrimary ? 3:1)
            .overlay{
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isPrimary ? Color.clear : Color.yellow.opacity(0.8), lineWidth: 1)
            }
        
    }
}


#Preview {
    RouteTimeAnnotation(time: "", isPrimary: true)
}
