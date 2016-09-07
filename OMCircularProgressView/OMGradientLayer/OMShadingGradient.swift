
//
//    Copyright 2015 - Jorge Ouahbi
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.
//


//
//  OMShadingGradient.swift
//
//  Created by Jorge Ouahbi on 20/4/16.
//  Copyright © 2016 Jorge Ouahbi. All rights reserved.
//


import Foundation
import UIKit

// function slope
typealias GradientSlopeFunction = (Double) -> Double

// interpolate two UIColors
typealias GradientInterpolationFunction = (UIColor,UIColor,CGFloat) -> UIColor

public enum GradientFunction {
    case Linear
    case Exponential
    case Cosine
}

func ShadingFunctionCreate(colors : [UIColor],
                            locations : [CGFloat],
                            slopeFunction: GradientSlopeFunction,
                              interpolationFunction: GradientInterpolationFunction) -> (UnsafePointer<CGFloat>, UnsafeMutablePointer<CGFloat>) -> Void
{
    return { inData, outData in
        let alpha = CGFloat(slopeFunction(Double(inData[0])))
        
        var positionIndex = 0;
        let colorCount    = colors.count
        var stop1Position = locations.first!
        var stop1Color    = colors[0]
        
        positionIndex += 1;
        
        var stop2Position = CGFloat(0.0)
        var stop2Color:UIColor;
        
        if (colorCount > 1) {
            stop2Color  = colors[1]
            
            // When originally are 1 location and 1 color.
            // Add the stop2Position to 1.0
                
            stop2Position  = (locations.count == 1) ? 1.0 : locations[1];
            positionIndex += 1;
                
        } else {
            // if we only have one value, that's what we return
            stop2Position = stop1Position;
            stop2Color    = stop1Color;
        }
        
        while (positionIndex < colorCount && stop2Position < alpha) {
            stop1Color      = stop2Color;
            stop1Position   = stop2Position;
            stop2Color      = colors[positionIndex]
            stop2Position   = locations[positionIndex]
            positionIndex  += 1;
        }
        
        if (alpha <= stop1Position) {
            // if we are less than our lowest position, return our first color
#if DEBUG_VERBOSE
            print("alpha:\(String(format:"%.1f",alpha)) <= position \(String(format:"%.1f",stop1Position)) color \(stop1Color.shortDescription)")
#endif
            outData[0] = stop1Color.components[0]
            outData[1] = stop1Color.components[1]
            outData[2] = stop1Color.components[2]
            outData[3] = stop1Color.components[3]
            
        } else if (alpha >= stop2Position) {
            // likewise if we are greater than our highest position, return the last color
#if DEBUG_VERBOSE
            print("alpha:\(String(format:"%.1f",alpha)) >= position \(String(format:"%.1f",stop2Position)) color \(stop1Color.shortDescription)")
#endif
            outData[0] = stop2Color.components[0]
            outData[1] = stop2Color.components[1]
            outData[2] = stop2Color.components[2]
            outData[3] = stop2Color.components[3]
            
        } else {
            
            // otherwise interpolate between the two
            let newPosition = (alpha - stop1Position) / (stop2Position - stop1Position);
            
            let newColor : UIColor = interpolationFunction(stop1Color, stop2Color, newPosition)
#if DEBUG_VERBOSE
            print("alpha:\(String(format:"%.1f",alpha)) position \(String(format:"%.1f",newPosition)) color \(newColor.shortDescription)")
#endif
            
            for componentIndex in 0 ..< 3 {
                outData[componentIndex] = newColor.components[componentIndex]
            }
            
            // The alpha component is always 1, the shading is always opaque.
            outData[3] = 1.0
        }
    }
}

func ShadingCallback(infoPointer: UnsafeMutablePointer<Void>, inData: UnsafePointer<CGFloat>, outData: UnsafeMutablePointer<CGFloat>) -> Void {
    
    var info = UnsafeMutablePointer<OMShadingGradient>(infoPointer).memory
    
    info.shadingFunction(inData, outData)
}


public struct OMShadingGradient {
    private var monotonicLocations:[CGFloat] = []
    let colors : [UIColor]
    let locations : [CGFloat]?
    let startPoint : CGPoint
    let endPoint : CGPoint
    let startRadius : CGFloat
    let endRadius : CGFloat
    let extendsPastStart:Bool
    let extendsPastEnd:Bool
    let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()!
    let slopeFunction: EasingFunctionsTuple
    let functionType : GradientFunction
    let gradientType : OMGradientType
    
     init(colors: [UIColor],
          locations: [CGFloat]?,
          startPoint: CGPoint,
          endPoint: CGPoint,
          extendStart: Bool = false,
          extendEnd: Bool = false,
          functionType: GradientFunction = .Linear,
          slopeFunction: EasingFunctionsTuple =  kEasingFunctionLinear) {
        
        self.init(colors:colors,
                  locations: locations,
                  startPoint: startPoint,
                  startRadius: 0,
                  endPoint: endPoint,
                  endRadius: 0,
                  extendStart: extendStart,
                  extendEnd: extendEnd,
                  gradientType: .Axial,
                  functionType: functionType,
                  slopeFunction: slopeFunction)
    }
    
     init(colors: [UIColor],
          locations: [CGFloat]?,
          startPoint: CGPoint,
          startRadius: CGFloat,
          endPoint: CGPoint,
          endRadius: CGFloat,
          extendStart: Bool = false,
          extendEnd: Bool = false,
          functionType: GradientFunction = .Linear,
          slopeFunction: EasingFunctionsTuple =  kEasingFunctionLinear) {
        
        self.init(colors:colors,
                  locations: locations,
                  startPoint: startPoint,
                  startRadius: startRadius,
                  endPoint: endPoint,
                  endRadius: endRadius,
                  extendStart: extendStart,
                  extendEnd: extendEnd,
                  gradientType: .Radial,
                  functionType: functionType,
                  slopeFunction: slopeFunction)
    }
    
    init(colors: [UIColor],
         locations: [CGFloat]?,
         startPoint: CGPoint,
         startRadius: CGFloat,
         endPoint: CGPoint,
         endRadius: CGFloat,
         extendStart: Bool,
         extendEnd: Bool,
         gradientType : OMGradientType  = .Axial,
         functionType : GradientFunction = .Linear,
         slopeFunction: EasingFunctionsTuple  =  kEasingFunctionLinear)
    {
        self.locations   = locations
        self.startPoint  = startPoint
        self.endPoint    = endPoint
        self.startRadius = startRadius
        self.endRadius   = endRadius
        
        // already checked in OMShadingGradientLayer
        assert(colors.count >= 2);
        
        // if only exist one color, duplicate it.
        if (colors.count == 1) {
            let color = colors.first!
            self.colors = [color,color];
        } else {
            self.colors = colors
        }
        
        // check the color space of all colors.
        if let lastColor = colors.last {
            for color in colors {
                // must be the same colorspace
                assert(lastColor.colorSpace?.model == color.colorSpace?.model,
                       "unexpected color model \(color.colorSpace?.model.name) != \(lastColor.colorSpace?.model.name)")
                // and correct model
                assert(color.colorSpace?.model == .RGB,"unexpected color space model \(color.colorSpace?.model.name)")
                if(color.colorSpace?.model != .RGB) {
                    //TODO: handle different color spaces
                    print("Unsupported color space. model: \(color.colorSpace?.model.name)")
                }
            }
        }
        
        self.slopeFunction  = slopeFunction
        self.functionType   = functionType
        self.gradientType   = gradientType
        self.extendsPastStart = extendStart
        self.extendsPastEnd   = extendEnd
        
        // handle nil locations
        if let locations = self.locations {
            if locations.count > 0 {
                monotonicLocations = locations
            }
        }
        
        // TODO(jom): handle different number colors and locations
        
        if (monotonicLocations.count == 0) {
            monotonicLocations = monotonic(colors.count)
        }
        
#if (DEBUG_VERBOSE)
        print("\(monotonicLocations.count) monotonic locations")
#endif
#if (DEBUG_VERBOSE)
        print(" \(monotonicLocations)")
#endif
    }
    
    lazy var shadingFunction : (UnsafePointer<CGFloat>, UnsafeMutablePointer<CGFloat>) -> Void = {
        var interpolationFunction:GradientInterpolationFunction =  UIColor.lerp
        switch(self.functionType){
        case .Linear :
            interpolationFunction =  UIColor.lerp
            break
        case .Exponential :
            interpolationFunction =  UIColor.eerp
            break
        case .Cosine :
            interpolationFunction =  UIColor.coserp
            break
        }
        return ShadingFunctionCreate(self.colors,
                                     locations: self.monotonicLocations,
                                     slopeFunction: self.slopeFunction.0,
                                     interpolationFunction: interpolationFunction )
    }()
    
    lazy var CGFunction : CGFunctionRef? = {
        var callbacks = CGFunctionCallbacks(version: 0, evaluate: ShadingCallback, releaseInfo: nil)
        return CGFunctionCreate(&self,  // info
            1,                          // domainDimension
            [0, 1],                     // domain
            4,                          // rangeDimension
            [0, 1, 0, 1, 0, 1, 0, 1],   // range
            &callbacks)                 // callbacks
    }()
    
    lazy var CGShading : CGShadingRef! = {

        var shading: CGShadingRef?
        var callbacks = CGFunctionCallbacks(version: 0, evaluate: ShadingCallback, releaseInfo: nil)
        if(self.gradientType == .Axial) {
            shading = CGShadingCreateAxial(self.colorSpace,
                                        self.startPoint,
                                        self.endPoint,
                                        self.CGFunction,
                                        self.extendsPastStart,
                                        self.extendsPastEnd)
        } else {
            assert(self.gradientType == .Radial)
            shading = CGShadingCreateRadial(self.colorSpace,
                                         self.startPoint,
                                         self.startRadius,
                                         self.endPoint,
                                         self.endRadius,
                                         self.CGFunction,
                                         self.extendsPastStart,
                                         self.extendsPastEnd)
        }
        
        return shading
    }()
}