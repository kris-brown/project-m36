import TutorialDInterpreter
import Test.HUnit
import RelationExpr
import Relation
import RelationalError
import RelationType
import qualified Data.HashSet as HS
import qualified Data.Map as M
import System.Exit

main = do 
  counts <- runTestTT (TestList tests)
  if errors counts + failures counts > 0 then exitFailure else exitSuccess
  where
    tests = map (\(tutd, expected) -> TestCase $ assertTutdEqual basicDatabaseContext expected tutd) simpleRelTests ++ map (\(tutd, expected) -> TestCase $ assertTutdEqual dateExamples expected tutd) dateExampleRelTests
    simpleRelTests = [("x:=true", Right relationTrue),
                      ("x:=false", Right relationFalse),
                      ("x:=true union false", Right relationTrue),
                      ("x:=true; x:=false", Right relationFalse),
                      ("x:=relation{a int}", mkRelation simpleAAttributes HS.empty),
                      ("x:=relation{c int} rename {c as d}", mkRelation simpleBAttributes HS.empty),
                      ("y:=relation{b int, c int}; x:=y{c}", mkRelation simpleProjectionAttributes HS.empty),
                      ("x:=relation{tuple{a char(\"spam\"), b int(5)}}", mkRelation simpleCAttributes (HS.fromList $ map RelationTuple [M.fromList [("a", StringAtom "spam"),("b",IntAtom 5)]])),
                      ("constraint failc true in false; x:=true", Left $ InclusionDependencyCheckError "failc"),
                      ("x:=y; x:=true", Left $ RelVarNotDefinedError "y"),
                      ("x:=true where true", Right relationTrue),
                      ("x:=true where false", Right relationFalse),
                      ("x:=true where true or false", Right relationTrue),
                      ("x:=true where false or false", Right relationFalse),
                      ("x:=true where true and false", Right relationFalse),
                      ("x:=true where true and true", Right relationTrue),
                      ("x:=true=true", Right relationTrue),
                      ("x:=true=false", Right relationFalse),
                      ("x:=true; undefine x", Left (RelVarNotDefinedError "x")),
                      ("x:=relation {b int, a char}; insert x relation{tuple{b int(5), a char(\"spam\")}}", mkRelation simpleCAttributes (HS.fromList [RelationTuple $ M.fromList [("a", StringAtom "spam"), ("b", IntAtom 5)]])),
                      ("x:=relation{tuple{b int(5),a char(\"spam\")},tuple{b int(6),a char(\"sam\")}}; delete x where b=6", mkRelation simpleCAttributes $ HS.fromList [RelationTuple $ M.fromList [("a", StringAtom "spam"), ("b", IntAtom 5)]])
                     ]
    simpleAAttributes = M.fromList [("a", Attribute "a" IntAtomType)]
    simpleBAttributes = M.fromList [("d", Attribute "d" IntAtomType)]
    simpleCAttributes = M.fromList [("a", Attribute "a" StringAtomType), ("b", Attribute "b" IntAtomType)]
    simpleProjectionAttributes = M.fromList [("c", Attribute "c" IntAtomType)]
    dateExampleRelTests = [("x:=S where true", Right s),
                           ("x:=S where CITY = \"London\"", restrict (\(RelationTuple tupMap) -> tupMap M.! "CITY" == StringAtom "London") s),
                           ("x:=S where false", Right $ Relation (attributes s) HS.empty),
                           ("a:=S; update a (STATUS:=50); x:=a{STATUS}", mkRelation (M.fromList [("STATUS", Attribute "STATUS" IntAtomType)]) (HS.fromList [RelationTuple $ M.fromList [("STATUS", IntAtom 50)]])),
                           ("x:=S; update x where SNAME=\"Blake\" (CITY:=\"Boston\")", relMap (\(RelationTuple tupMap) -> RelationTuple $ if tupMap M.! "SNAME" == StringAtom "Blake" then M.insert "CITY" (StringAtom "Boston") tupMap else tupMap) s)
                          ]

assertTutdEqual databaseContext expected tutd = assertEqual tutd expected interpreted
  where
    interpreted = case interpret databaseContext tutd of 
      (Just err, _) -> Left err
      (Nothing, context) -> case M.lookup "x" (relationVariables context) of
        Nothing -> Left $ RelVarNotDefinedError "x"
        Just rel -> Right rel 