module Lines exposing (Config, Axis, Interpolation(..), line, viewSimple, view, viewCustom)

{-|

# Lines

## Quick start
@docs viewSimple

## Customize individual lines
@docs view, line

## Customize plot
@docs viewCustom, Config, Axis, Interpolation

-}

import Html
import Svg
import Svg.Attributes
import Lines.Color as Color
import Lines.Axis as Axis
import Lines.Junk as Junk
import Lines.Dot as Dot
import Lines.Coordinate as Coordinate exposing (..)
import Lines.Container as Container
import Internal.Coordinate as Coordinate
import Internal.Attributes as Attributes
import Internal.Interpolation as Interpolation
import Internal.Path as Path
import Internal.Axis as Axis
import Internal.Junk


{-| -}
type alias Config data msg =
  { container : Container.Config msg
  , junk : Junk.Junk msg
  , x : Axis data msg
  , y : Axis data msg
  , interpolation : Interpolation
  }


{-| -}
type alias Axis data msg =
  { look : Axis.Look msg
  , variable : data -> Float
  }


{-| -}
type Interpolation
  = Linear
  | Monotone



-- LINE


{-| -}
type Line data msg =
  Line (LineConfig data msg)


{-| TODO: Should Color be the same as the dot? -}
line : Color.Color -> Int -> Dot.Dot msg -> List data -> Line data msg
line color width dot data =
  Line <| LineConfig color width dot data



-- VIEW


{-| -}
viewSimple : (data -> Float) -> (data -> Float) -> List (List data) -> Svg.Svg msg
viewSimple toX toY datas =
  view toX toY (List.map2 defaultConfig Color.defaults datas)


{-| -}
view : (data -> Float) -> (data -> Float) -> List (Line data msg) -> Svg.Svg msg
view toX toY =
  viewCustom
    { container = Container.default
    , x = Axis Axis.defaultLook toX
    , y = Axis Axis.defaultLook toY
    , junk = Junk.none
    , interpolation = Linear
    }


{-| -}
viewCustom : Config data msg -> List (Line data msg) -> Svg.Svg msg
viewCustom config lines =
  let
    -- Points
    points =
      List.map (List.map point << .data << lineConfig) lines

    point datum =
      Point
        (config.x.variable datum)
        (config.y.variable datum)

    -- System
    allPoints =
      List.concat points

    system =
      { frame = config.container.frame
      , x = Coordinate.limits .x allPoints
      , y = Coordinate.limits .y allPoints
      }

    -- View
    junk =
      Internal.Junk.getLayers config.junk allPoints system

    container plot =
      Html.div [] (plot :: junk.html)

    attributes =
      List.append
        (Attributes.toSvgAttributes system config.container.attributes)
        [ Svg.Attributes.width <| toString system.frame.size.width
        , Svg.Attributes.height <| toString system.frame.size.height
        ]

    viewLines =
      List.map2 (viewLine config system) lines points
  in
  container <|
    Svg.svg attributes
      [ Svg.defs [] config.container.defs
      , Svg.g [ Svg.Attributes.class "junk--below" ] junk.below
      , Svg.g [ Svg.Attributes.class "lines" ] viewLines
      , Axis.viewHorizontal system config.x.look
      , Axis.viewVertical system config.y.look
      , Svg.g [ Svg.Attributes.class "junk--above" ] junk.above
      ]



-- INTERNAL


type alias LineConfig data msg =
  { color : Color.Color
  , width : Int
  , dot : Dot.Dot msg
  , data : List data
  }


lineConfig : Line data msg -> LineConfig data msg
lineConfig (Line lineConfig) =
  lineConfig


defaultConfig : Color.Color -> List data -> Line data msg
defaultConfig color data =
  Line
    { dot = Dot.dot (Dot.default color)
    , color = color
    , width = 2
    , data = data
    }


viewLine : Config data msg -> Coordinate.System -> Line data msg -> List Point -> Svg.Svg msg
viewLine config system line points =
  Svg.g
    [ Svg.Attributes.class "line" ]
    [ viewInterpolation config system line points
    , viewDots system line points
    ]


viewInterpolation : Config data msg -> Coordinate.System -> Line data msg -> List Point -> Svg.Svg msg
viewInterpolation config system (Line line) points =
  let
    interpolationCommands =
      case config.interpolation of
        Linear ->
          Interpolation.linear points

        Monotone ->
          Interpolation.monotone points

    commands =
      case points of
        first :: rest ->
          Path.Move first :: interpolationCommands

        [] ->
          []

    attributes =
      [ Svg.Attributes.class "interpolation"
      , Svg.Attributes.stroke line.color
      , Svg.Attributes.strokeWidth (toString line.width)
      , Svg.Attributes.fill "transparent"
      ]
  in
  Path.view system attributes commands


viewDots : Coordinate.System -> Line data msg -> List Point -> Svg.Svg msg
viewDots system (Line line) points =
   Svg.g
    [ Svg.Attributes.class "dots" ] <|
    List.map (Dot.view system line.dot) points