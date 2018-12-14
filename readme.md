Music from the web
==================

**An electronic sculpture**

*A spider was sitting in the center of her web*

*Waiting for diner to be served*

*While listening to music.*

*To feel or not to feel vibrations*

*For her was the question*


Project description
-------------------

The circuit will be assembled on the cone of a 4" speaker. The microcontroller, an 8 pins SOIC, will be suspended in center with 30 AWG wires going out from it to
circumference. An octogonal wooden rim glued to the rim of speaker will support the components and the spider web. 

Electronic circuit
------------------

![schematic](schematic.png)

 At the heart of the circuit a **PIC12F1572** microcontroller. This MCU has 3 independants 16 bits PWM (*Pulse widh modulation*) peripherals. One of them is used to generate audio tones.
A second is used to control musical note duration. The third one as no relation du music. I given him a bit-play role as a LED show controller with the assistance
of CWG (*Complementary Waveform Generator*) peripheral. So that every MCU pins are in use.

**Tone generation** is easy with a PWM. The period is set to that of desired audio frequency with a 50% duty cycle. This audio tone is outputted on pin **6**.

**Envelope** is tone rise and fall time. This control is true transistor **Q1** which base is polarized by **C4** electrolytic capacitor voltage. The rise speed is
controlled by **R3**, **D3** and the decay speed by **R2**, **D2**. A the beginning of each musical note pin **5** goes high by virtue of a PWM signal. This charge
**C4** hence controller the output volume to **speaker**.  This voltage is sustained for some fraction of note duration. After the sustain period pin **5** goes low
and **C4** discharge thrue **R2**, **D2** thus gradualy dimishing speaker volume.

Light show
----------

The audio circuit using only 2 pins there 3 left and I decided to use them. pin **2** and **3** output a rectangular waveform 180&deg; out of phase comming form the
**CWG** which is feed form the third PWM. The frequency of which is 200Hertz with at continuously varying duty cycle in a triangular shape. The output of this PWM is
on pin **7** and feed **D5** LED. The effect is varying intensity off the LED producing a heart beat effect.

But the same signal on pins **2** and **3** has a complelely different effect on bicolors LEDs **D4** and **D6**. the effect is of a gradual color change from RED to 
green passing thrue orange. The 2 LEDs are wired so that their color phase is 180&deg; out.

using the music box
-------------------
 The box containt a list of tunes. At power up the first is played. At the end of it the microcontroller fall in sleep mode. In this mode it draws less than 1µA. Pressing
the **reset** button wake it up and the next tune in the list is played after what the microcontroller fall asleep again. At the end of the list the pointer loop back
to the first one.


Coding
======



 

