; Minecraft-style local camera. Global initialization has no game side effects.
; All entry points and helpers use native static HS syntax, without parameters.
(global short view 0)
(global boolean was_down false)
(global boolean down false)

(script static void frame
    (input_claim (settings_string "controller"))
    (set down (or (input_held (settings_string "keyboard"))
                  (input_held (settings_string "controller"))))
    (if (and down (= was_down false))
        (begin
            (set view (+ view 1))
            (if (> view 2) (set view 0))))
    (set was_down down)
    ; Seats and death retain their own cameras. The runtime resets the requested
    ; view each frame, so first person requires no camera side effect here.
    (if (and (> view 0) (camera_free) (player_alive)
             (= (player_in_vehicle) false))
        (camera_view (settings_real "distance") (settings_real "height")
                     (= view 2) (= view 1))))

(script static void stop
    (set view 0)
    (set was_down false))
