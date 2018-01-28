/*
    zfast_crt_standard_vertical - A simple, fast CRT shader for vertical games.

    Copyright (C) 2017 Greg Hogan (SoltanGris42)

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.


Notes:  This shader does scaling with a weighted linear filter for adjustable
	sharpness on the x and y axes based on the algorithm by Inigo Quilez here:
	http://http://www.iquilezles.org/www/articles/texture/texture.htm
	but modified to be somewhat sharper.  Then a scanline effect that varies
	based on pixel brighness is applied along with a monochrome aperture mask.
	This shader runs at 60fps on the Raspberry Pi 3 hardware at 2mpix/s
	resolutions (1920x1080 or 1600x1200).
	 
	The vertical version adds a rotated aperture mask for vertical games
	on horizontal monitors.
*/

//For testing compilation 
//#define FRAGMENT
//#define VERTEX

#define FINEMASK
//#define BLACK_OUT_BORDER
#define VERTICAL

// Compatibility #ifdefs needed for parameters
#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

// Parameter lines go here:
#pragma parameter BLURSCALEX "Blur Amount X-Axis" 0.30 0.0 1.0 0.05
#pragma parameter LOWLUMSCAN "Scanline Darkness - Low" 6.0 0.0 10.0 0.5
#pragma parameter HILUMSCAN "Scanline Darkness - High" 8.0 0.0 50.0 1.0
#pragma parameter BRIGHTBOOST "Dark Pixel Brightness Boost" 1.25 0.5 1.5 0.05
#pragma parameter MASK_DARK "Mask Effect Amount" 0.25 0.0 1.0 0.05
#pragma parameter MASK_FADE "Mask/Scanline Fade" 0.8 0.0 1.0 0.05

#ifdef PARAMETER_UNIFORM
// All parameter floats need to have COMPAT_PRECISION in front of them
uniform COMPAT_PRECISION float BLURSCALEX;
uniform COMPAT_PRECISION float LOWLUMSCAN;
uniform COMPAT_PRECISION float HILUMSCAN;
uniform COMPAT_PRECISION float BRIGHTBOOST;
uniform COMPAT_PRECISION float MASK_DARK;
uniform COMPAT_PRECISION float MASK_FADE;
#else
#define BLURSCALEX 0.45
#define LOWLUMSCAN 5.0
#define HILUMSCAN 10.0
#define BRIGHTBOOST 1.25
#define MASK_DARK 0.25
#define MASK_FADE 0.8
#endif

#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#define COMPAT_VARYING varying 
#define COMPAT_ATTRIBUTE attribute 
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 COLOR;
COMPAT_ATTRIBUTE vec4 TexCoord;
COMPAT_VARYING vec4 COL0;
COMPAT_VARYING vec4 TEX0;
// out variables go here as COMPAT_VARYING whatever
COMPAT_VARYING float maskFade;
COMPAT_VARYING vec2 invDims;

vec4 _oPosition1; 
uniform mat4 MVPMatrix;
uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

// compatibility #defines
#define vTexCoord TEX0.xy
#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutSize vec4(OutputSize, 1.0 / OutputSize)

void main()
{
    gl_Position = MVPMatrix * VertexCoord;
	
	TEX0.xy = (TexCoord.xy);
	maskFade = 0.3333*MASK_FADE;
	invDims = 1.0/TextureSize.xy;
}

#elif defined(FRAGMENT)

#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;
uniform sampler2D Texture;
COMPAT_VARYING vec4 TEX0;
// in variables go here as COMPAT_VARYING whatever
COMPAT_VARYING float maskFade;
COMPAT_VARYING vec2 invDims;

// compatibility #defines
#define Source Texture
#define vTexCoord TEX0.xy
#define texture(c, d) COMPAT_TEXTURE(c, d)
#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutSize vec4(OutputSize, 1.0 / OutputSize)

// delete all 'params.' or 'registers.' or whatever in the fragment

void main()
{

	//This is just like "Quilez Scaling" but sharper
	COMPAT_PRECISION vec2 p = vTexCoord * TextureSize;
	COMPAT_PRECISION vec2 i = floor(p) + 0.50;
	COMPAT_PRECISION vec2 f = p - i;
	p = (i + 4.0*f*f*f)*invDims;
	p.x = mix( p.x , vTexCoord.x, BLURSCALEX);
	COMPAT_PRECISION float Y = f.y*f.y;
	COMPAT_PRECISION float YY = Y*Y;
	
#if defined(FINEMASK) 
#if defined(VERTICAL)
	COMPAT_PRECISION float whichmask = fract( gl_FragCoord.y*-0.4999);
#else
	COMPAT_PRECISION float whichmask = fract( gl_FragCoord.x*-0.4999);
#endif
	COMPAT_PRECISION float mask = 1.0 + float(whichmask < 0.5) * -MASK_DARK;
#else
#if defined(VERTICAL)
	COMPAT_PRECISION float whichmask = fract(gl_FragCoord.y * -0.3333);
#else
	COMPAT_PRECISION float whichmask = fract(gl_FragCoord.x * -0.3333);
#endif
	COMPAT_PRECISION float mask = 1.0 + float(whichmask <= 0.33333) * -MASK_DARK;
#endif

	COMPAT_PRECISION vec3 colour = texture(Source, p).rgb;
	
	COMPAT_PRECISION float scanLineWeight = (BRIGHTBOOST - LOWLUMSCAN*(Y - 2.05*YY));
	COMPAT_PRECISION float scanLineWeightB = 1.0 - HILUMSCAN*(YY-2.8*YY*Y);	
	
#if defined(BLACK_OUT_BORDER)
	colour.rgb*=float(tc.x > 0.0)*float(tc.y > 0.0); //why doesn't the driver do the right thing?
#endif

	FragColor.rgb = colour.rgb*mix(scanLineWeight*mask, scanLineWeightB, dot(colour.rgb,vec3(maskFade)));
	
} 
#endif
