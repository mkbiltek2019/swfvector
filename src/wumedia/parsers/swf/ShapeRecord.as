﻿/*
 * Copyright 2009 (c) Guojian Miguel Wu, guojian@wu-media.com | guojian.wu@ogilvy.com
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */
package wumedia.parsers.swf {
	import flash.display.Graphics;	import flash.display.Shape;	import flash.geom.Rectangle;	
	/**
	 * ...
	 * @author guojian@wu-media.com | guojian.wu@ogilvy.com
	 */
	public class ShapeRecord {
		static private var _shape	:Shape = new Shape();
		
		static public function drawShape(graphics:*, shape:ShapeRecord, scale:Number = 1.0, offsetX:Number = 0.0, offsetY:Number = 0.0):void {
			var elems:Array = shape._elements;
			var elemNum:int = -1;
			var elemLen:int = elems.length;
			var dx:int = 0;
			var dy:int = 0;
			scale *= .05;
			while ( ++elemNum < elemLen ) {
				if ( elems[elemNum] is Edge )  {
					var edge:Edge = elems[elemNum];
					if ( dx != edge.sx || dy != edge.sy ) {
						graphics["moveTo"](offsetX + edge.sx * scale, offsetY + edge.sy * scale);
					}
					edge.apply(graphics, scale, offsetX, offsetY);
					dx = edge.x;
					dy = edge.y;
				} else if ( elems[elemNum] is FillStyle ) {
					(elems[elemNum] as FillStyle).apply(graphics, scale, offsetX, offsetY);
				} else if ( elems[elemNum] is LineStyle ) {
					(elems[elemNum] as LineStyle).apply(graphics);
				}
			}
		}
		
		public function ShapeRecord(data:Data, tagType:uint) {
			_tagType = tagType;
			_hasStyle = _tagType == TagTypes.DEFINE_SHAPE
						|| _tagType == TagTypes.DEFINE_SHAPE2
						|| _tagType == TagTypes.DEFINE_SHAPE3
						|| _tagType == TagTypes.DEFINE_SHAPE4;
			_hasAlpha = _tagType == TagTypes.DEFINE_SHAPE3
						|| _tagType == TagTypes.DEFINE_SHAPE4;
			_hasExtendedFill = _tagType == TagTypes.DEFINE_SHAPE2
						|| _tagType == TagTypes.DEFINE_SHAPE3
						|| _tagType == TagTypes.DEFINE_SHAPE4;
			_hasStateNewStyle = _tagType == TagTypes.DEFINE_SHAPE2
						|| _tagType == TagTypes.DEFINE_SHAPE3;
						
			parse(data);
			if ( _elements.length > 0 ) {
				calculateBounds();
			} else {
				_bounds = new Rectangle(0, 0, 0, 0);
			}
		}
		
		private var _tagType				:uint;
		private var _fillBits				:uint;
		private var _lineBits				:uint;
		private var _hasStyle				:Boolean;
		private var _hasAlpha				:Boolean;
		private var _hasExtendedFill		:Boolean;
		private var _hasStateNewStyle		:Boolean;
		private var _elements				:Array;
		private var _bounds					:Rectangle;
		private var _fills					:Array;
		private var _lines					:Array;
		private var _fill0					:Array;
		private var _fill1					:Array;
		private var _fill0Index				:uint;
		private var _fill1Index				:uint;
		
		private function parse(data:Data):void {
			var stateMoveTo:Boolean;
			var stateFillStyle0:Boolean;
			var stateFillStyle1:Boolean;
			var stateLineStyle:Boolean;
			var stateNewStyles:Boolean;
			var moveBits:uint;
			var fillStyle0:int;
			var fillStyle1:int;
			var lineStyle:int;
			var flags:uint;
			var dx:int = 0;
			var dy:int = 0;
			var edge:Edge;
			_elements = new Array();
			_fills = new Array();
			_lines = new Array();
			data.synchBits();
			if ( _hasStyle ) {
				parseStyles(data);
				data.synchBits();
			} else {
				_fills = [[]];
				_fill0 = [];
				_fill0Index = 0;
			}
			_fillBits = data.readUBits(4);
			_lineBits = data.readUBits(4);
			while ( true ) {
				var type:uint = data.readUBits(1);
				if ( type == 1 ) {
					// Edge shape-record
					edge = new Edge(data.readUBits(1) == 0 ? Edge.CURVE : Edge.LINE, data, dx, dy);
					if ( _fill0 ) {
						_fill0.push(edge.reverse());
					}
					if ( _fill1 ) {
						_fill1.push(edge);
					}
					dx = edge.x;
					dy = edge.y;
				} else {
					// Change Record or End
					flags = data.readUBits(5);
					if ( flags == 0 ) {
						// end
						break;
					}
					stateMoveTo = (flags & 0x01) != 0;
					stateFillStyle0 = (flags & 0x02) != 0;
					stateFillStyle1 = (flags & 0x04) != 0;
					stateLineStyle = (flags & 0x08) != 0;
					stateNewStyles = (flags & 0x10) != 0;
					if ( stateMoveTo ) {
						moveBits = data.readUBits(5);
						dx = data.readSBits(moveBits);
						dy = data.readSBits(moveBits);
					}
					if ( stateFillStyle0 ) {
						fillStyle0 = data.readUBits(_fillBits);
					}
					if ( stateFillStyle1 ) {
						fillStyle1 = data.readUBits(_fillBits);
					}
					if ( stateLineStyle ) {
						lineStyle = data.readUBits(_lineBits);
					}
					if ( _hasStyle ) {
						queueEdges();
						_fill0Index = fillStyle0 - 1;
						if ( fillStyle0 > 0 && _fills[_fill0Index] ) {
							_fill0 = [];
						} else {
							_fill0 = null;
						}
						_fill1Index = fillStyle1 - 1;
						if ( fillStyle1 > 0 && _fills[_fill1Index] ) {
							_fill1 = [];
						} else {
							_fill1 = null;
						}
					}
					if ( _hasStateNewStyle && stateNewStyles ) {
						parseStyles(data);
						_fillBits = data.readUBits(4);
						_lineBits = data.readUBits(4);
					}
				}
			}
			saveEdges();
		}
		

		private function parseStyles(data:Data):void {
			var i:int;
			var num:int;
			saveEdges();
			num = data.readUnsignedByte();
			if ( _hasExtendedFill && num == 0xff ) {
				num = data.readUnsignedShort();
			}
			for ( i = 0; i < num; ++i ) {
				_fills.push([new FillStyle(data, _hasAlpha)]);
			}
			num = data.readUnsignedByte();
			if ( num == 0xff ) {
				num = data.readUnsignedShort();
			}
			for ( i = 0; i < num; ++i ) {
				_lines.push([new LineStyle(_tagType == TagTypes.DEFINE_SHAPE4 ? LineStyle.TYPE_2 : LineStyle.TYPE_1, data, _hasAlpha)]);
			}
		}
		
		/**
		 * Add the current edges back to the fill arrays and wait to be saved
		 * @private
		 */
		private function queueEdges():void {
			if ( _fill0 ) {
				_fills[_fill0Index] = _fills[_fill0Index].concat(_fill0);
			}
			if( _fill1 ) {
				_fills[_fill1Index] = _fills[_fill1Index].concat(_fill1);
			}
		}
		
		/**
		 * Sort and save the fill edges
		 * @private
		 */
		private function saveEdges():void {
			queueEdges();
			var i:int;
			var l:int;
			l = _fills.length;
			i = -1;
			while ( ++i < l ) {
				_fills[i] = sortEdges(_fills[i]);
				_elements = _elements.concat(_fills[i]);
			}
			_fills = new Array();
			_lines = new Array();
		}
		
		private function sortEdges(arr:Array):Array {
			var i:int;
			var j:int;
			var edge:Edge;
			var elem:*;
			var sorted:Array = [];
			arr.reverse();
			while (!((elem = arr.pop()) is Edge)) {
				sorted.push(elem);
			}
			sorted.push(edge = elem as Edge);
			j = arr.length;
			while ( j > 0 ) {
				while ( --j > -1 ) {
					i = arr.length;
					while ( --i > -1 ) {
						if ( edge.x == arr[i].sx && edge.y == arr[i].sy ) {
							edge = arr.splice(i,1)[0];
							sorted.push(edge);
							continue;
						}
					}
				}
				j = arr.length;
				if (j > 0) {
					sorted.push(edge = arr.pop());
				}
			}
			return sorted;
		}
		
		private function calculateBounds():void {
			var g:Graphics = _shape.graphics;
			g.clear();
			g.beginFill(0);
			drawShape(g, this);
			g.endFill();
			_bounds = _shape.getRect(_shape);
		}
		
		public function get elements():Array { return _elements; }
		public function get bounds():Rectangle { return _bounds; }
	}
	
}