module node;

abstract class Node
{
    Node[] children;
    Node parent;
}

class None : Node {}