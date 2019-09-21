{-# LANGUAGE OverloadedLabels  #-}
{-# LANGUAGE OverloadedLists   #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import           Data.Text                      ( Text )
import qualified Data.Text                     as T
import qualified Data.Text.IO                  as T
import qualified Data.Text.Encoding            as T
import           Control.Monad
import           GI.Gtk                         ( Window(..)
                                                , TextView(..)
                                                , FileChooserWidget(..)
                                                , ToolButton(..)
                                                , Box(..)
                                                , Label(..)
                                                , Orientation(..)
                                                , Align(..)
                                                , ScrolledWindow(..)
                                                , TextBuffer(..)
                                                , fileChooserGetFilename
                                                )
import           Control.Concurrent.Async       ( async )
import qualified GI.Gdk                        as Gdk
import qualified GI.Gtk                        as Gtk
import qualified Data.ByteString.Char8         as BS
import           GI.Gtk.Declarative
import           GI.Gtk.Declarative.App.Simple
import           Paths_bene

data State = Welcome | FileSelection | Blank | Editing (IO TextBuffer)

data Event = Closed | FileSelected (Maybe FilePath) | NewDocument | OpenDocument

bufferFromFile :: FilePath -> IO TextBuffer
bufferFromFile filename = do
  buffer   <- Gtk.textBufferNew Gtk.noTextTagTable-- [TODO] Implement tag table.
  contents <- T.readFile filename
  Gtk.textBufferSetText buffer contents $ byteLength contents
  return buffer
  where byteLength = fromIntegral . BS.length . T.encodeUtf8

view' :: State -> AppView Window Event
view' s =
  bin
      Window
      [ #title := "Bene"
      , on #deleteEvent (const (True, Closed))
      , #widthRequest := 480
      , #heightRequest := 300
      ]
    $ case s of
        Welcome ->
          container Box [#orientation := OrientationHorizontal]
            $ [ expandableChild $ widget
                ToolButton
                [ #iconName := "document-new"
                , on #clicked NewDocument
                , classes ["intro"]
                ]
              , expandableChild $ widget
                ToolButton
                [ #iconName := "document-open"
                , on #clicked OpenDocument
                , classes ["intro"]
                ]
              ]
        FileSelection -> widget
          FileChooserWidget
          [onM #fileActivated (fmap FileSelected . fileChooserGetFilename)]
        Blank -> bin ScrolledWindow []
          $ widget TextView [#wrapMode := Gtk.WrapModeWord, classes ["editor"]]
        Editing buffer -> bin ScrolledWindow [] $ widget
          TextView
          [ afterCreated $ \tv -> Gtk.textViewSetBuffer tv . Just =<< buffer
          , #wrapMode := Gtk.WrapModeWord
          , classes ["editor"]
          ]

expandableChild :: Widget a -> BoxChild a
expandableChild =
  BoxChild defaultBoxChildProperties { expand = True, fill = True }

update' :: State -> Event -> Transition State Event
update' _ (FileSelected (Just file)) =
  Transition (Editing $ bufferFromFile file) (return Nothing)
update' s (FileSelected Nothing) = Transition s (return Nothing)
update' _ NewDocument            = Transition Blank (return Nothing)
update' _ OpenDocument           = Transition FileSelection (return Nothing)
update' _ Closed                 = Exit

main :: IO ()
main = do
  void $ Gtk.init Nothing

  path     <- T.pack <$> getDataFileName "themes/giorno/giorno.css"

  screen   <- maybe (fail "No screen?") return =<< Gdk.screenGetDefault
  provider <- Gtk.cssProviderNew
  Gtk.cssProviderLoadFromPath provider path
  Gtk.styleContextAddProviderForScreen
    screen
    provider
    (fromIntegral Gtk.STYLE_PROVIDER_PRIORITY_USER)

  void . async $ do
    void $ runLoop app
    Gtk.mainQuit
  Gtk.main
 where
  app =
    App { view = view', update = update', inputs = [], initialState = Welcome }
