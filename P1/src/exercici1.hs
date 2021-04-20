import Drawing 

myDrawing :: Drawing
myDrawing = colored green (translated 0 (-1.5) (solidCircle 1)) <> colored red (translated 0 (1.5) (solidCircle 1))

main :: IO()
main = svgOf myDrawing
