# SIM Configuration

The Network Management System (NMS) automates the generation of the following mandatory SIM attributes for subscriber creation:
IMSI, Derived Operator Code (OPc), Subscriber Authentication Key (Ki), and Sequence Number.

## IMSI 

The International Mobile Subscriber Identity (IMSI) is a unique identifier for subscribers. It consists of 15 or 16 digits, formed by concatenating the following:

- Mobile Country Code (MCC): 3 digits, taken from the Network Slice configuration where the subscriber is registered.
- Mobile Network Code (MNC): 2 or 3 digits, also taken from the Network Slice configuration.
- Mobile Subscription Identification Number (MSIN): 10 digits, randomly generated.

## OPc and Key

The Derived Operator Code (OPc) is generated using the 5G Authentication Algorithm Milenage.
The result is a 32-character hexadecimal number.

The Key (Ki) corresponds to the value used to generate the OPc. It is also a 32-character hexadecimal number.

## Sequence Number

The Sequence Number is a randomly generated 12-character hexadecimal number.