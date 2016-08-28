/*

OOPointer.m
Oolite


Copyright (C) 2008 Jens Ayton

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

#import "OOPointer.h"
#import "OOColor.h"
#import "OOCollectionExtractors.h"
#import "Universe.h"
#import "PlayerEntity.h"
#import "MyOpenGLView.h"
#import "OOMacroOpenGL.h"


@interface OOPointer (Private)

- (void) setUpDataWithPoints:(NSArray *)points
					   scale:(GLfloat)scale
					   color:(OOColor *)color
				overallAlpha:(GLfloat)alpha;

- (void) setUpData2WithScale:(GLfloat)scale
					   color:(OOColor *)color
				overallAlpha:(GLfloat)alpha;


- (void) setUpDataForOnePoint:(NSArray *)pointInfo
						scale:(GLfloat)scale
				   colorComps:(float[4])colorComps
				 overallAlpha:(GLfloat)alpha
						 data:(GLfloat *)ioBuffer;

- (NSArray *) crosshairDefinitionForPointer;

@end


@implementation OOPointer

- (id) initWithScale:(GLfloat)scale
		       color:(OOColor *)color
		overallAlpha:(GLfloat)alpha
{
    NSArray *points = nil;

	if ((self = [super init]))
	{
		if (alpha > 0.0f && (color == nil || [color alphaComponent] != 0.0f))
		{
            points = [self crosshairDefinitionForPointer];
			[self setUpDataWithPoints:points scale:scale color:color overallAlpha:alpha];
			[self setUpData2WithScale:scale color:color overallAlpha:alpha];
		}
	}

	return self;
}

#define FBOX(x) [NSNumber numberWithFloat:x]

- (NSArray *) crosshairDefinitionForPointer
{
    GLfloat a = 0.5;

    NSMutableArray *result = nil;

    result = [NSMutableArray arrayWithObjects: nil];

    float r = 0.15;
    int num_segments = 32;
    float theta = 2 * 3.1415926 / (float)num_segments;
    float c = cosf(theta);
    float s = sinf(theta);
    float t;

    float lx = 0, ly = 0;

    float x = r;
    float y = 0;
    for (int i = 0; i < num_segments + 1; i++)
    {
        if (i != 0)
        {
            NSArray *line = [NSArray arrayWithObjects: FBOX(a), FBOX(lx), FBOX(ly), FBOX(a), FBOX(x), FBOX(y), nil];
            [result addObject: line];
        }

        lx = x; ly = y;

        t = x;
        x = c * x - s * y;
        y = s * t + c * y;
    }

    x = r / 10;
    y = 0;
    for (int i = 0; i < num_segments + 1; i++)
    {
        if (i != 0)
        {
            NSArray *line = [NSArray arrayWithObjects: FBOX(a), FBOX(lx), FBOX(ly), FBOX(a), FBOX(x), FBOX(y), nil];
            [result addObject: line];
        }

        lx = x; ly = y;

        t = x;
        x = c * x - s * y;
        y = s * t + c * y;
    }

    return result;
}


- (void) dealloc
{
	free(_data);

	[super dealloc];
}


- (void) render
{
	if (_data != NULL)
	{
		OO_ENTER_OPENGL();
		OOSetOpenGLState(OPENGL_STATE_OVERLAY);

		OOGL(glPushAttrib(GL_ENABLE_BIT));
		OOGL(glDisable(GL_LIGHTING));
		OOGL(glDisable(GL_TEXTURE_2D));
		OOGLPushModelView();
        int mx, my;
        SDL_GetMouseState(&mx, &my);
        GLfloat x_offset = [[UNIVERSE gameView] x_offset];
        GLfloat y_offset = [[UNIVERSE gameView] y_offset];
        GLfloat x = ((GLfloat)mx - x_offset);
        GLfloat y = -((GLfloat)my - y_offset);
		OOGLTranslateModelView(make_vector(x, y, [[UNIVERSE gameView] display_z]));

        OOGL(glVertexPointer(2, GL_FLOAT, sizeof (GLfloat) * 6, _data));
		OOGL(glColorPointer(4, GL_FLOAT, sizeof (GLfloat) * 6, _data + 2));

		OOGL(glEnableClientState(GL_VERTEX_ARRAY));
		OOGL(glEnableClientState(GL_COLOR_ARRAY));

		OOGL(glDrawArrays(GL_LINES, 0, _count * 2));

		OOGL(glDisableClientState(GL_VERTEX_ARRAY));
		OOGL(glDisableClientState(GL_COLOR_ARRAY));

		OOGLPopModelView();

        MyOpenGLView *gameView = [UNIVERSE gameView];
        BOOL capsLockCustomView = [UNIVERSE viewDirection] == VIEW_CUSTOM && [gameView isCapsLockOn];
        BOOL mouse_control_on = [PLAYER isMouseControlOn];
        if (([gameView isLeftButtonDownAWhile] || mouse_control_on) && !capsLockCustomView)
        {
            GLfloat r = sqrt(x*x + y*y);
            GLfloat a = atan(y/x);
            if (x < 0)
                a += M_PI;
            for (int i = 0; i < 6; i++)
            {
                OOGLPushModelView();
                OOGLRotateModelView(a, make_vector(0, 0, 1));
                OOGLTranslateModelView(make_vector((i + 1) * (r / 8), 0, [[UNIVERSE gameView] display_z]));
                GLfloat s = 1.0 / (7 - i);
                OOGLScaleModelView(make_vector(s, s, s));

                OOGL(glVertexPointer(2, GL_FLOAT, sizeof (GLfloat) * 6, _data2));
                OOGL(glColorPointer(4, GL_FLOAT, sizeof (GLfloat) * 6, _data2 + 2));

                OOGL(glEnableClientState(GL_VERTEX_ARRAY));
                OOGL(glEnableClientState(GL_COLOR_ARRAY));

                OOGL(glDrawArrays(GL_LINES, 0, _count2 * 2));

                OOGL(glDisableClientState(GL_VERTEX_ARRAY));
                OOGL(glDisableClientState(GL_COLOR_ARRAY));

                OOGLPopModelView();
            }
        }

		OOGL(glPopAttrib());

		OOVerifyOpenGLState();
		OOCheckOpenGLErrors(@"OOPointer after rendering");
	}
}


- (void) setUpDataWithPoints:(NSArray *)points
					   scale:(GLfloat)scale
					   color:(OOColor *)color
				overallAlpha:(GLfloat)alpha
{
	NSUInteger				i;
	float					colorComps[4] = { 0.0f, 1.0f, 0.0f, 1.0f };
	GLfloat					*data = NULL;

	_count = [points count];
	if (_count == 0)  return;

	_data = malloc(sizeof (GLfloat) * 12 * _count);	// 2 coordinates, 4 colour components for each endpoint of each line segment
	[color getRed:&colorComps[0] green:&colorComps[1] blue:&colorComps[2] alpha:&colorComps[3]];

	// Turn NSArray into GL-friendly element array
	data = _data;
	for (i = 0; i < _count; i++)
	{
		[self setUpDataForOnePoint:[points oo_arrayAtIndex:i]
							 scale:scale
						colorComps:colorComps
					  overallAlpha:alpha
							  data:data];
		data += 12;
	}
}

- (void) setUpData2WithScale:(GLfloat)scale
					   color:(OOColor *)color
				overallAlpha:(GLfloat)alpha
{
	float					colorComps[4] = { 0.0f, 1.0f, 0.0f, 1.0f };
	GLfloat					*data = NULL;
    GLfloat a = 0.5;

	_count2 = 2;

	_data2 = malloc(sizeof (GLfloat) * 12 * _count2);	// 2 coordinates, 4 colour components for each endpoint of each line segment
	[color getRed:&colorComps[0] green:&colorComps[1] blue:&colorComps[2] alpha:&colorComps[3]];

	data = _data2;
    NSArray *line1 = [NSArray arrayWithObjects: FBOX(a), FBOX(0), FBOX(-1.0), FBOX(a), FBOX(1.0), FBOX(0), nil];
    [self setUpDataForOnePoint:line1
                         scale:scale
                    colorComps:colorComps
                  overallAlpha:alpha
                          data:data];
    data += 12;

    NSArray *line2 = [NSArray arrayWithObjects: FBOX(a), FBOX(1.0), FBOX(0), FBOX(a), FBOX(0), FBOX(1.0), nil];
    [self setUpDataForOnePoint:line2
                         scale:scale
                    colorComps:colorComps
                  overallAlpha:alpha
                          data:data];
    data += 12;
}


- (void) setUpDataForOnePoint:(NSArray *)pointInfo
						scale:(GLfloat)scale
				   colorComps:(float[4])colorComps
				 overallAlpha:(GLfloat)alpha
						 data:(GLfloat *)ioBuffer
{
	GLfloat					x1, y1, a1, x2, y2, a2;
	GLfloat					r, g, b, a;

	if ([pointInfo count] >= 6)
	{
		a1 = [pointInfo oo_floatAtIndex:0];
		x1 = [pointInfo oo_floatAtIndex:1] * scale;
		y1 = [pointInfo oo_floatAtIndex:2] * scale;
		a2 = [pointInfo oo_floatAtIndex:3];
		x2 = [pointInfo oo_floatAtIndex:4] * scale;
		y2 = [pointInfo oo_floatAtIndex:5] * scale;
		r = colorComps[0];
		g = colorComps[1];
		b = colorComps[2];
		a = colorComps[3];

		/*	a1/a2 * a is hud.plist and crosshairs.plist - specified alpha,
			which must be clamped to 0..1 so the plist-specified alpha can't
			"escape" the overall alpha range. The result of scaling this by
			overall HUD alpha is then clamped again for robustness.
		 */
		a1 = OOClamp_0_1_f(OOClamp_0_1_f(a1 * a) * alpha);
		a2 = OOClamp_0_1_f(OOClamp_0_1_f(a2 * a) * alpha);
	}
	else
	{
		// Bad entry, write red point in middle.
		x1 = -0.01f;
		x2 = 0.01f;
		y1 = y2 = 0.0f;
		r = 1.0f;
		g = b = 0.0f;
		a1 = a2 = 1.0;
	}

	*ioBuffer++ = x1;
	*ioBuffer++ = y1;
	*ioBuffer++ = r;
	*ioBuffer++ = g;
	*ioBuffer++ = b;
	*ioBuffer++ = a1;

	*ioBuffer++ = x2;
	*ioBuffer++ = y2;
	*ioBuffer++ = r;
	*ioBuffer++ = g;
	*ioBuffer++ = b;
	*ioBuffer++ = a2;

	(void)ioBuffer;
}

@end
