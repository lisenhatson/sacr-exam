#!/bin/bash

case "$1" in
    start)
        sacr-start
        ;;
    finish)
        sacr-finish
        ;;
    grade)
        sacr-grade
        ;;
    *)
        echo ""
        echo "SACR Exam System"
        echo ""
        echo "Usage:"
        echo "  sacr start"
        echo "  sacr finish"
        echo "  sacr grade"
        echo ""
        ;;
esac
