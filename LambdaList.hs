-- ######################################################
-- #                                                    #
-- #	== LambdaList ==                                #
-- #                                                    #
-- #    Ein kleines Haskellprogramm; geeignet um die    #
-- #    Getränkeliste der Fachschaft Technik an der     #
-- #    Uni Bielefeld zu managen.                       #
-- #                                                    #
-- #	Geschrieben von Jonas Betzendahl, 2013          #
-- #    jbetzend@techfak.uni-bielefeld.de               #
-- #                                                    #
-- #	Lizenz: CC0 / Public Domain                     #
-- #                                                    #
-- ######################################################

module Main where

import Data.List            (intercalate, sort)
import Data.List.Split      (splitOn)

import System.IO
import System.Directory     (doesFileExist)
import System.Console.ANSI  (clearScreen)

-- TODOS:
--
-- --> Inactive counters on skipping
-- --> Make new File on no list found
-- --> Replicate empty rows in latex file
-- --> Fix LaTeX errors
-- --> Fix rounding errors for negative balances

-- NICE TO HAVES:
--
-- --> implement, Question function, refactor

-- Kung-Fu mit Typen

type Name       = String
type Counter    = Int
type Default    = Bool

data NInterp    = NNull | NNothing
data TColor     = TBlue | TGreen | TRed | TYellow
data Trinker    = Trinker Name Guthaben Counter
data Guthaben   = Guthaben Int

instance Eq Trinker where
    (Trinker a _ _) == (Trinker x _ _) = (a == x)

instance Ord Trinker where
    compare (Trinker a _ _)  (Trinker x _ _) = compare a x

instance Show Guthaben where
    show (Guthaben n) = (show (div n 100)) ++ "." ++ (reverse . (take 2) . reverse) (show n)

instance Show Trinker where
    show (Trinker a b c) = intercalate ";" [a, (show b), (show c)]

-- Datei - Ein- und Ausgabe

parseListe :: FilePath -> IO [Trinker] 
parseListe fp = do a <- readFile fp
                   return $ map parseTrinker $ map (splitOn ";") (lines a)
    where
      parseTrinker :: [String] -> Trinker
      parseTrinker [x,y,z] = case (cleanGuthaben y) of Just u  -> case readInt NNothing z of Just k  -> Trinker x (Guthaben u) k
                                                                                             Nothing -> error $ "Parsingfehler bei Guthaben hier: " ++ z
                                                       Nothing -> error $ "Parsingfehler! Unkorrekter Betrag hier: " ++ concat [x,y,z]
      parseTrinker _       = error "Parsingfehler: inkorrekte Anzahl Elemente in mindestens einer Zeile"

writeFiles :: [Trinker] -> IO()
writeFiles trinker = let strinker = sort trinker in
                         do writeFile "mateliste.txt" $ unlines $ map show (strinker)
                            writeFile "mateliste.tex" $ unlines $ [latexHeader] ++ (map toLaTeX (strinker)) ++ [latexFooter]

toLaTeX :: Trinker -> String
toLaTeX (Trinker nm gb@(Guthaben b) _)
    | b < (-1000) = "\\rowcolor{dunkelgrau}\n" ++ ltxrw
    | b < 0       = "\\rowcolor{hellgrau}\n"   ++ ltxrw
    | otherwise   =                               ltxrw
      where
        ltxrw :: String
        ltxrw = nm ++ "&" ++ (show gb) ++ "& & & & & & \\ \n \\hline"

latexHeader :: String
latexHeader = "\\documentclass[a4paper,10pt,landscape]{article}\n\\usepackage[utf8]{inputenc}"
              ++ "\\usepackage{german}\n\\usepackage{longtable}\n\\usepackage{eurosym}"
              ++ "\\usepackage{color}\n\\usepackage{colortbl}\n\\usepackage{geometry}"
              ++ "\n\\geometry{a4paper,left=0mm,right=0mm, top=0.25cm, bottom=0.25cm}"
              ++ "\n\\definecolor{dunkelgrau}{rgb}{0.6,0.6,0.6}\n\\definecolor{hellgrau}{rgb}{0.8,0.8,0.8}"
              ++ "\n\\begin{document}\n\\begin{longtable}{|l|p{3cm}|p{5cm}|l|l|p{2cm}|p{2cm}|p{2cm}|}\n\\hline"
              ++ "\n\\textbf{Login} & Guthaben & Club Mate (0,90 \\euro) & Cola \\slash\\ Brause (0,70 \\euro)"
              ++ "& Schokor. (0,50 \\euro) & 0,20 \\euro & 0,10 \\euro & 0,05 \\euro\n\\hline\n\\hline\n"

latexFooter :: String
latexFooter =  "\\end{longtable}\\bigskip"
               ++ "\\begin{center} \n Neue Trinker tragen sich bitte im Stil vom TechFak-Login ein.\\\\"
               ++ "(1. Buchstabe des Vornamens + 7 Buchstaben des Nachnamens (oder voller Nachname)) \\bigskip \\\\"
               ++ "\\textbf{Je mehr Geld in der Kasse, desto schneller gibt es neue Getränke!} \\\\"
               ++ "\\textbf{Also seid so freundlich und übt bitte ein bisschen \\glqq peer pressure\\grqq\\ auf die Leute im Minus aus.}\n"
               ++ "\\end{center} \n \\end{document}"

-- Helferfunktionen und Trivialitäten

readInt :: NInterp -> String -> Maybe Int
readInt NNull    "" = Just 0
readInt NNothing "" = Nothing
readInt _        xs = case reads xs of [(n, "")] -> Just n
                                       _         -> Nothing

showColor :: TColor -> String -> String
showColor clr txt = case clr of TRed    -> "\x1b[31m" ++ txt ++ "\x1b[0m"
                                TGreen  -> "\x1b[32m" ++ txt ++ "\x1b[0m"
                                TYellow -> "\x1b[33m" ++ txt ++ "\x1b[0m"
                                TBlue   -> "\x1b[34m" ++ txt ++ "\x1b[0m"

showMoney :: Guthaben -> String
showMoney gld@(Guthaben betr)
    | (betr < 0) = showColor TRed   $ show gld
    | otherwise  = showColor TGreen $ show gld

showTrinkerInfo :: Trinker -> IO ()
showTrinkerInfo (Trinker nm gld ctr) = putStrLn $ "\nDer User " ++ (showColor TBlue nm) ++ inac ++ " hat derzeit einen Kontostand von " ++ (showMoney gld) ++ "."
    where
      inac :: String
      inac = if ctr == 0 then "" else " (" ++ (show ctr) ++ " Mal inaktiv)"

cleanGuthaben :: String -> Maybe Int
cleanGuthaben s = case readInt NNull $ filter (not . (flip elem ",.")) s
                       of {Just n -> Just n ; _ -> Nothing}

parseGuthaben :: String 
parseGuthaben = undefined

-- Hauptprogrammlogik:

processTrinker :: Trinker -> [Int] -> IO Trinker 
processTrinker (Trinker nm (Guthaben gld) cntr) werte@[enzhlng, nnzg, sbzg, fnfzg, zwnzg, zhn, fnf]
               = if null werte then do return $ Trinker nm (Guthaben gld)                          (cntr+1) -- increase "inactive" counter
                               else do return $ Trinker nm (Guthaben (gld + enzhlng - vertrunken)) 0        -- set new balance and reset counter
    where
      vertrunken = sum $ zipWith (*) [90, 70, 50, 20, 10, 5] (tail werte)

getAmounts :: Name -> IO [Int]
getAmounts nm = mapM (abfrage nm) fragen
    where
      fragen :: [String]
      fragen = ("\n-- Wie viel Geld hat " ++ nm ++ " eingezahlt? "):(map (strichFragen nm) ["90", "70", "50", "20", "10", " 5"])
     
      strichFragen :: Name -> String -> String
      strichFragen nm amnt = "-- Wie viele Striche hat " ++ nm ++ " in der Spalte für " ++ amnt ++ " Cent? "

      abfrage :: Name -> String -> IO Int
      abfrage nm frg = do putStr frg 
                          x <- getLine
                          case readInt NNull x of Just n  -> return n
                                                  Nothing -> putStrLn "-- Eingabe unklar!" >> abfrage nm frg

newTrinker :: IO Trinker
newTrinker = do putStrLn "Neuer Trinker wird erstellt."
                x <- askName
                y <- askDouble
                putStr $ "Bitte geben Sie \"ok\" zum Bestätigen ein: Trinker " ++ (showColor TBlue x) ++ " mit einem Kontostand von " ++ (showMoney (Guthaben y)) ++ "  "
                o <- getLine
                if o == "ok" then return $ Trinker x (Guthaben y) 0 else putStrLn "Bestätigung nicht erhalten. Neuer Versuch:\n" >> newTrinker
                   where askName :: IO String
                         askName = do putStr "Bitte geben Sie einen Nicknamen ein: " ; n <- getLine
                                      case n of {"" -> askName ; x -> return x}

                         askDouble :: IO Int
                         askDouble = do putStr "Bitte geben Sie einen validen Kontostand ein: " ; l <- getLine
                                        case readInt NNull l of {Just d -> return d ; _ -> askDouble}

listLoop :: IO [Trinker] -> Int -> IO ()
listLoop xs i = do
                as <- xs
                if i >= length as 
                   then do putStrLn $ "\n!! Sie haben das " ++ (showColor TYellow "Ende") ++ " der aktuellen Liste erreicht. !!"
                           putStr   $ "!! Bitte wählen sie aus: speichern/b(e)enden | (a)bbrechen | (n)euer Trinker | (z)urück : "
                           c <- getLine
                           case head c of
                                'e' -> do putStr "Wirklich beenden (bisherige Änderungen werden geschrieben)? Bitte geben Sie \"ok\" ein: " ; q <- getLine
                                          if q == "ok" then writeFiles as else putStrLn "Doch nicht? Okay, weiter geht's!" >> listLoop xs i

                                'a' -> do putStr "Wirklich abbrechen (bisherige Änderungen werden verworfen)? Bitte geben Sie \"ok\" ein: " ; q <- getLine
                                          if q == "ok" then putStrLn "Dann bis zum nächsten Mal! :)" else putStrLn "Doch nicht? Okay, weiter geht's!" >> listLoop xs i
                               
                                'n' -> do neu <- newTrinker ; listLoop (return (as ++ [neu])) (i)

                                'z' -> let z q = min (i-q) 0 in case ((readInt NNothing) . tail) c of {Nothing -> listLoop xs (z 1); Just n -> listLoop xs (z n)}

                                _   -> putStrLn "Eingabe nicht verstanden. Ich wiederhole: " >> listLoop xs i
  
                   else do let tr = (head . drop i) as
                           showTrinkerInfo tr
                           putStr "Bitte wählen Sie aus! (a)bbrechen | (b)earbeiten | b(e)enden | (l)öschen | übe(r)schreiben | (v)or | (z)urück : "
                           c <- getLine
                           case c of
                                "a"    -> do putStr "Wirklich abbrechen (bisherige Änderungen werden verworfen)? Bitte geben Sie \"ok\" ein: " ; q <- getLine
                                             if q == "ok" then putStrLn "Dann bis zum nächsten Mal! :)" else putStrLn "Doch nicht? Okay, weiter geht's!" >> listLoop xs i

                                "e"    -> do putStr "Wirklich beenden (bisherige Änderungen werden geschrieben)? Bitte geben Sie \"ok\" ein: " ; q <- getLine
                                             if q == "ok" then writeFiles as else putStrLn "Doch nicht? Okay, weiter geht's!" >> listLoop xs i

                                "l"    -> do putStr $ "Bitte geben Sie \"ok\" ein um " ++ (showColor TBlue ((\(Trinker nm _ _) -> nm) tr)) ++ " aus der Liste entfernen: " ; q <- getLine
                                             if q == "ok" then listLoop (return ((take i as) ++ (drop (i+1) as))) i else listLoop xs i  

                                "r"    -> do neu <- newTrinker ; listLoop (return ((take i as) ++ neu:(drop (i+2) as))) i

                                "b"    -> let foobar ti p = do putStr $ "Bitte geben Sie \"ok\" zum Bestätigen ein: " ; q <- getLine
                                                               case q of "ok" -> listLoop (return ((take i as) ++ p : (drop (i+1) as))) (i+1)
                                                                         ""   -> foobar ti p
                                                                         _    -> putStr "Vorgang abgebrochen. Wiederhole:" >> listLoop xs i
                                          in do p <- (\(Trinker a b c) -> (getAmounts a >>= processTrinker (Trinker a b c))) tr
                                                showTrinkerInfo p ; foobar tr p

                                'v':as -> let z q = min (i+q) (length as) in case ((readInt NNothing) . tail) c of {Nothing -> listLoop xs (z 1); Just n -> listLoop xs (z n)}
                                'z':bs -> let z q = max (i-q) 0           in case ((readInt NNothing) . tail) c of {Nothing -> listLoop xs (z 1); Just n -> listLoop xs (z n)}

                                ""     -> listLoop xs (min (i+1) (length as))
                                _      -> putStr "Eingabe nicht verstanden. Ich wiederhole: " >> listLoop xs i

main :: IO()
main = do clearScreen
          hSetBuffering stdout NoBuffering

          putStrLn "Willkommen, User!"
          putStrLn "Dies ist ein automatisches Matelistenprogramm. Bitte beantworten Sie die Fragen auf dem Schirm."
          putStr   "Scanne Verzeichnis nach vorhandener mateliste.txt ... "
          f <- doesFileExist "mateliste.txt" 
          if f 
             then putStrLn " Liste gefunden!" >> listLoop (parseListe "mateliste.txt") 0
             else putStrLn " keine Liste gefunden. Wollen Sie eine neue anlegen?"                                 --TODO: Make new file!