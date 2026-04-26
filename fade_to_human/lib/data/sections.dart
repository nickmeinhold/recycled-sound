import 'package:flutter/material.dart';

import 'section.dart';

/// Nick's speaking sections — one idea per screen, one screen per swipe.
const sections = [
  // --- SLIDE 6: THE COLLABORATION ---

  SpeakingSection(
    index: 0,
    slideRef: 'SLIDE 6  ·  1 of 12',
    text:
        "I'm Nick. I build AI tools for healthcare. When Seray "
        "described this problem, I knew it was exactly the kind of "
        "thing AI automation can solve.",
    emoji: '\u{1F468}\u{200D}\u{2695}\u{FE0F} \u{1F4BB}',
    keyword: 'DOCTOR + DEVELOPER',
    color: Color(0xFF004D40),
    backgroundImages: ['assets/slides/image9.jpeg'],
  ),

  SpeakingSection(
    index: 1,
    slideRef: 'SLIDE 6  ·  2 of 12',
    text:
        "Together we defined the problem.",
    emoji: '\u{1F91D} \u{1F50D}',
    keyword: 'DEFINE THE PROBLEM',
    color: Color(0xFF004D40),
    backgroundImages: ['assets/slides/image9.jpeg'],
  ),

  SpeakingSection(
    index: 2,
    slideRef: 'SLIDE 6  ·  3 of 12',
    text:
        "There are thousands of hearing aids sitting in drawers across "
        "Australia — devices that people no longer use, that still work, "
        "that could change someone's life.",
    emoji: '\u{1F442} \u{1F4E6} \u{2728}',
    keyword: 'THOUSANDS IN DRAWERS',
    color: Color(0xFF004D40),
    backgroundImages: ['assets/slides/image10.jpeg'],
  ),

  SpeakingSection(
    index: 3,
    slideRef: 'SLIDE 6  ·  4 of 12',
    text:
        "The problem isn't supply. The problem is the bottleneck in between.",
    emoji: '\u{26A0}\u{FE0F} \u{1F50D}',
    keyword: 'THE BOTTLENECK',
    color: Color(0xFF004D40),
    backgroundImages: ['assets/slides/image10.jpeg'],
  ),

  SpeakingSection(
    index: 4,
    slideRef: 'SLIDE 6  ·  5 of 12',
    text:
        "Donated hearing aids arrive unlabelled. They come in all shapes, "
        "sizes, and generations.",
    emoji: '\u{1F4E6} \u{2753} \u{2753} \u{2753}',
    keyword: 'UNLABELLED',
    color: Color(0xFF004D40),
    backgroundImages: ['assets/slides/image10.jpeg'],
  ),

  SpeakingSection(
    index: 5,
    slideRef: 'SLIDE 6  ·  6 of 12',
    text:
        "Figuring out what you've got — what brand, what model, what "
        "generation, whether it's still clinically viable — that takes a "
        "trained audiologist.",
    emoji: '\u{1F9D1}\u{200D}\u{2695}\u{FE0F} \u{1FA7A}',
    keyword: 'TRAINED AUDIOLOGIST',
    color: Color(0xFF004D40),
    backgroundImages: ['assets/slides/image9.jpeg'],
  ),

  SpeakingSection(
    index: 6,
    slideRef: 'SLIDE 6  ·  7 of 12',
    text:
        "And every hour spent sorting is an hour not spent with people.",
    emoji: '\u{23F3} \u{2260} \u{1F9D1}\u{200D}\u{1F91D}\u{200D}\u{1F9D1}',
    keyword: 'HOURS NOT WITH PEOPLE',
    color: Color(0xFF004D40),
    backgroundImages: ['assets/slides/image9.jpeg'],
  ),

  SpeakingSection(
    index: 7,
    slideRef: 'SLIDE 6  ·  8 of 12',
    text: "So I built something to handle the detective work.",
    emoji: '\u{1F575}\u{FE0F}',
    keyword: 'THE DETECTIVE WORK',
    color: Color(0xFF004D40),
    backgroundImages: ['assets/slides/image9.jpeg'],
  ),

  // --- SLIDE 7 → 8: THE SOLUTION ---

  SpeakingSection(
    index: 8,
    slideRef: 'SLIDE 7\u21928  ·  9 of 12',
    text:
        "The Recycled Sound App uses AI to identify hearing aid models from "
        "a photo — the brand, the model, the generation — so the audiologist "
        "can skip straight to the question that actually matters: is this the "
        "right device for this person?",
    emoji: '\u{1F4F1} \u{1F916} \u{1F4F7} \u{2705}',
    keyword: 'THE RIGHT DEVICE',
    color: Color(0xFF1A237E),
    backgroundImages: ['assets/slides/image12.png'],
  ),

  SpeakingSection(
    index: 9,
    slideRef: 'SLIDE 7\u21928  ·  10 of 12',
    text: "Our volunteers don't need to be technicians.",
    emoji: '\u{1F64B} \u{1F6AB} \u{1F527}',
    keyword: 'NOT TECHNICIANS',
    color: Color(0xFF1A237E),
    backgroundImages: ['assets/slides/image12.png'],
  ),

  SpeakingSection(
    index: 10,
    slideRef: 'SLIDE 7\u21928  ·  11 of 12',
    text:
        "They can walk in, use the app, and move straight on to the work "
        "that actually needs a human being — sitting with someone, building "
        "trust, making a connection.",
    emoji: '\u{1F6B6} \u{1F4F1} \u{1F91D} \u{2764}\u{FE0F}',
    keyword: 'HUMAN CONNECTION',
    color: Color(0xFF1A237E),
    backgroundImages: ['assets/slides/image13.png'],
  ),

  // --- SLIDE 9: THE POINT ---

  SpeakingSection(
    index: 11,
    slideRef: 'SLIDE 9  ·  12 of 13',
    text:
        "Because that's what this is really about. The technology exists so "
        "the people can show up for people.",
    emoji: '\u{1F4A1} \u{1F916} \u{27A1}\u{FE0F} \u{1F9D1}\u{200D}\u{1F91D}\u{200D}\u{1F9D1}',
    keyword: 'PEOPLE FOR PEOPLE',
    color: Color(0xFFBF360C),
    backgroundImages: ['assets/slides/image14.png'],
  ),

  SpeakingSection(
    index: 12,
    slideRef: 'SLIDE 9  ·  13 of 13',
    text:
        "I trained as a doctor for seven years. I still want to help "
        "people — and now I've found a way to collaborate with a team "
        "and help a lot more of them.",
    emoji: '\u{1F468}\u{200D}\u{2695}\u{FE0F} \u{0037}\u{FE0F}\u{20E3} \u{2764}\u{FE0F} \u{1F30F}',
    keyword: 'A LOT MORE OF THEM',
    color: Color(0xFFBF360C),
    backgroundImages: ['assets/slides/image14.png'],
  ),
];
